# Andromeda Venue Implementation Example

This file documents how the abstraction layer pattern was applied to the Andromeda Venue system.

## Abstract Base Class

Defined in `notebooks/andromeda/venue/venue.py`:

```python
class Venue(abc.ABC):
    """Abstract base class for all venue interactions."""
    
    @abc.abstractmethod
    def submit_order(self, intent: OrderIntent, *, bar: BarRow) -> FillEvent | object:
        """Submit an order to the venue."""
        raise NotImplementedError

    @abc.abstractmethod
    def cancel_order(self, order_id: str) -> None:
        """Cancel an order by its venue-specific ID."""
        raise NotImplementedError

    @abc.abstractmethod
    def fetch_open_orders(self, symbol: Pair) -> List[dict]:
        """Retrieve resting (open) orders for a symbol."""
        raise NotImplementedError

    @abc.abstractmethod
    def fetch_portfolio(self, symbol: Pair) -> dict:
        """Get the current portfolio/position for a symbol."""
        raise NotImplementedError

    @abc.abstractmethod
    def is_dry_run(self) -> bool:
        """Check if the venue is operating in dry-run mode."""
        raise NotImplementedError
```

## Concrete Implementation: HyperliquidVenue

Implemented in `notebooks/andromeda/venue/hl/venue.py`:

```python
class HyperliquidVenue(Venue):
    """Hyperliquid venue implementation using Nautilus Trader for live trading."""
    
    def __init__(
        self,
        *,
        config: VenueConfig,
        paper: PaperExecutionAdapter | None = None,
        live_executor: object | None = None,
    ) -> None:
        if config.venue != "hl":
            raise VenueConfigError(f"Expected venue 'hl', got {config.venue!r}")
        self._config = config
        self._paper = paper if paper is not None else PaperExecutionAdapter()
        self._live = live_executor
        # Load credentials if not in dry-run
        if not self.is_dry_run():
            self._credentials = config.load_credentials()
            if self._credentials is None:
                raise VenueConfigError("Hyperliquid venue requires credentials")

    @property
    def is_dry_run(self) -> bool:
        return self._config.is_paper

    def submit_order(self, intent: OrderIntent, *, bar: BarRow) -> FillEvent | object:
        if self.is_dry_run:
            return self._paper.fill(intent, bar)
        
        forbid_live_under_dry_run(
            dry_run=self.is_dry_run, attempting_live=True
        )
        if self._live is None:
            msg = "live submit requires NtOrderPort when dry_run is False"
            raise VenueConfigError(msg)
        return self._live.submit(intent)
    
    # Other methods follow similar pattern...
```

## Integration: BotRunner Refactoring

Modified `notebooks/andromeda/bot/runner.py`:

```python
# Before
live: _LivePort | None = None
# ...
return HlOrderSubmit(dry_run=self.dry_run, live=self.live).submit(intent, bar=bar)

# After  
venue: Venue | None = None  # Changed from live: _LivePort | None to venue: Venue | None
# ...
def venue_submit(self, intent: OrderIntent, *, bar: BarRow) -> FillEvent | object:
    if self.dry_run:
        assert_dry_run_blocks_live(dry_run=True, live_submit_invoked=False)
    if self.venue is None:
        # If no venue is provided, create a default paper venue for backward compatibility
        from andromeda.execution.paper import PaperExecutionAdapter
        from andromeda.venue.venue import HyperliquidVenue
        from andromeda.venue.config import VenueConfig
        config = VenueConfig(venue="hl")
        paper_adapter = PaperExecutionAdapter()
        venue = HyperliquidVenue(config=config, paper=paper_adapter)
        return venue.submit_order(intent, bar=bar)
    return self.venue.submit_order(intent, bar=bar)
```

## Key Learnings

1. **Start Simple**: Implement one concrete class fully before creating others to ensure the abstract interface is correct
2. **Early Integration**: Update the consuming code (BotRunner) early to test the abstraction works
3. **Configuration Handling**: Each implementation should handle its own configuration loading
4. **Backward Compatibility**: Provide sensible defaults when no venue is explicitly configured
5. **Error Handling**: Use existing error types (VenueConfigError) for consistency
6. **Dry-run Guards**: Reuse existing guards like `forbid_live_under_dry_run` for consistency