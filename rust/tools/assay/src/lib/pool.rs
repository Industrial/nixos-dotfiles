//! Bounded concurrency for Nix evaluator subprocesses (wave 3).

use std::sync::atomic::{AtomicUsize, Ordering};
use std::sync::{Arc, Condvar, Mutex};

use crate::verdict::InfraError;

/// Tracks in-flight worker slots for observability and mock assertions.
#[derive(Debug, Default)]
pub struct PoolStats {
    in_flight: AtomicUsize,
    max_in_flight: AtomicUsize,
}

impl PoolStats {
    pub fn in_flight(&self) -> usize {
        self.in_flight.load(Ordering::SeqCst)
    }

    pub fn max_in_flight(&self) -> usize {
        self.max_in_flight.load(Ordering::SeqCst)
    }

    fn enter(&self) {
        let cur = self.in_flight.fetch_add(1, Ordering::SeqCst) + 1;
        let mut max = self.max_in_flight.load(Ordering::SeqCst);
        while cur > max {
            match self.max_in_flight.compare_exchange_weak(
                max,
                cur,
                Ordering::SeqCst,
                Ordering::SeqCst,
            ) {
                Ok(_) => break,
                Err(observed) => max = observed,
            }
        }
    }

    fn leave(&self) {
        self.in_flight.fetch_sub(1, Ordering::SeqCst);
    }
}

struct PoolInner {
    available: Mutex<usize>,
    cvar: Condvar,
    stats: Arc<PoolStats>,
}

/// RAII guard releasing a worker slot.
pub struct PoolGuard {
    inner: Arc<PoolInner>,
    on_drop: Option<Box<dyn FnOnce() + Send>>,
}

impl Drop for PoolGuard {
    fn drop(&mut self) {
        self.inner.stats.leave();
        if let Some(f) = self.on_drop.take() {
            f();
        } else {
            let mut avail = self.inner.available.lock().unwrap();
            *avail += 1;
            self.inner.cvar.notify_one();
        }
    }
}

/// Bounded pool of concurrent Nix worker slots.
pub trait NixWorkerPool: Send + Sync {
    fn acquire(&self) -> Result<PoolGuard, InfraError>;
    fn max_concurrency(&self) -> usize;
    fn stats(&self) -> &PoolStats;
}

/// Condvar-backed live pool (default max = CPU count).
pub struct SemaphoreWorkerPool {
    inner: Arc<PoolInner>,
    max: usize,
}

impl SemaphoreWorkerPool {
    pub fn new(max_concurrency: usize) -> Self {
        let max = max_concurrency.max(1);
        Self {
            inner: Arc::new(PoolInner {
                available: Mutex::new(max),
                cvar: Condvar::new(),
                stats: Arc::new(PoolStats::default()),
            }),
            max,
        }
    }

    pub fn default_live() -> Self {
        Self::new(num_cpus())
    }
}

impl NixWorkerPool for SemaphoreWorkerPool {
    fn acquire(&self) -> Result<PoolGuard, InfraError> {
        let mut avail = self.inner.available.lock().unwrap();
        while *avail == 0 {
            avail = self.inner.cvar.wait(avail).map_err(|_| {
                InfraError::Worker("worker pool lock poisoned".into())
            })?;
        }
        *avail -= 1;
        drop(avail);
        self.inner.stats.enter();
        Ok(PoolGuard {
            inner: Arc::clone(&self.inner),
            on_drop: None,
        })
    }

    fn max_concurrency(&self) -> usize {
        self.max
    }

    fn stats(&self) -> &PoolStats {
        &self.inner.stats
    }
}

/// Mock pool for unit tests — records peak in-flight; optional blocking for concurrency proofs.
pub struct MockWorkerPool {
    stats: Arc<PoolStats>,
    max: usize,
    active: Arc<Mutex<usize>>,
    block_ms: Mutex<u64>,
}

impl MockWorkerPool {
    pub fn new(max_concurrency: usize) -> Self {
        Self {
            stats: Arc::new(PoolStats::default()),
            max: max_concurrency.max(1),
            active: Arc::new(Mutex::new(0)),
            block_ms: Mutex::new(0),
        }
    }

    pub fn set_block_ms(&self, ms: u64) {
        *self.block_ms.lock().unwrap() = ms;
    }

    pub fn max_in_flight(&self) -> usize {
        self.stats.max_in_flight()
    }
}

impl NixWorkerPool for MockWorkerPool {
    fn acquire(&self) -> Result<PoolGuard, InfraError> {
        {
            let mut active = self.active.lock().unwrap();
            if *active >= self.max {
                return Err(InfraError::Worker(format!(
                    "mock pool saturated (max {})",
                    self.max
                )));
            }
            *active += 1;
        }
        self.stats.enter();
        let block = *self.block_ms.lock().unwrap();
        if block > 0 {
            std::thread::sleep(std::time::Duration::from_millis(block));
        }
        let active = Arc::clone(&self.active);
        Ok(PoolGuard {
            inner: Arc::new(PoolInner {
                available: Mutex::new(0),
                cvar: Condvar::new(),
                stats: Arc::clone(&self.stats),
            }),
            on_drop: Some(Box::new(move || {
                *active.lock().unwrap() -= 1;
            })),
        })
    }

    fn max_concurrency(&self) -> usize {
        self.max
    }

    fn stats(&self) -> &PoolStats {
        &self.stats
    }
}

fn num_cpus() -> usize {
    std::thread::available_parallelism()
        .map(|n| n.get())
        .unwrap_or(4)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn mock_pool_records_max_in_flight() {
        let pool = Arc::new(MockWorkerPool::new(2));
        let g1 = pool.acquire().unwrap();
        let g2 = pool.acquire().unwrap();
        assert_eq!(pool.max_in_flight(), 2);
        drop(g1);
        drop(g2);
        assert_eq!(pool.max_in_flight(), 2);
    }

    #[test]
    fn mock_pool_rejects_when_saturated() {
        let pool = MockWorkerPool::new(1);
        let _g = pool.acquire().unwrap();
        assert!(pool.acquire().is_err());
    }

    #[test]
    fn semaphore_pool_default_max_is_at_least_one() {
        let pool = SemaphoreWorkerPool::new(0);
        assert_eq!(pool.max_concurrency(), 1);
    }
}
