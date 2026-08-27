# Andromeda Venue System Abstraction

## Core Concept
The Andromeda Venue system uses an interface-like abstraction where the system asks a Venue to perform jobs (like submitting orders), and venue-specific implementations handle the details.

## Implementation Details

### Venue Contract
- Defined in `notebooks/andromeda/venue/hl/orders.py` as `NtOrderPort` Protocol:
  ```python
  class NtOrderPort(Protocol):
      """Minimal NT ExecutionEngine seam (submit OrderIntent)."""
      def submit(self, intent: OrderIntent) -> object: ...
  ```

### Usage Pattern
- In `notebooks/andromeda/bot/runner.py`, the `BotRunner.venue_submit` method:
  1. Uses paper execution when `dry_run=True`
  2. Delegates to live venue port when `dry_run=False`
  3. Requires a live port implementing `NtOrderPort` for live trading

### Venue Implementations
- **Hyperliquid**: Uses Nautilus Trader via `nautilus_trader.adapters.hyperliquid` (see `notebooks/andromeda/venue/hl/instruments.py`)
- **IBKR/CME**: Likely similar Nautilus-based implementations (directories exist for both)

### Key Benefits
1. **Seamless switching** between paper/live via configuration
2. **Encapsulation** of venue-specific logic (credentials, API details)
3. **Testability** through mock/paper implementations
4. **Extensibility** for new venues by implementing the port interface

### Configuration
- Managed through `notebooks/andromeda/venue/config.py`:
  - `VenueConfig` holds venue identifier and credentials path
  - Supports paper venue (no credentials needed)
  - Requires credentials_path for live venues (HL, IBKR, CME)

## Ongoing Abstraction Work
A venue abstraction layer is being introduced via Maestro task `tsk-mswzb1si-grotve` that will:
- Define an abstract base class `Venue` with standard methods
- Create concrete implementations for HL, IBKR, and CME venues
- Refactor `BotRunner` to depend on the abstract `Venue` class
- Maintain compatibility with existing `VenueConfig`

## Verification
- Dry-run guards prevent live trading when `dry_run=True`
- Venue-specific tests validate implementation correctness
- Integration tests ensure proper delegation between layers