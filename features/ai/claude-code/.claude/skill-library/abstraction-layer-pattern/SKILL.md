---
name: abstraction-layer-pattern
description: Pattern for implementing abstraction layers with multiple implementations in Python codebases, following dependency inversion principles.
category: development
---

# Abstraction Layer Pattern

## When to Use

Use this pattern when:
- You have multiple similar implementations (e.g., different venues, services, adapters)
- The rest of the code interacts with these implementations through a common interface
- You want to decouple the core logic from specific implementation details
- You need to add new implementations without changing existing code
- You want to facilitate testing by allowing mock implementations

## Trigger Conditions

- Multiple classes with similar methods but different implementations
- Code that uses conditionals or type-checking to handle different implementations
- Need to add a new implementation that follows the same pattern
- Difficulty testing due to tight coupling to specific implementations
- Desire to follow Dependency Inversion Principle (depend on abstractions, not concretions)

## Step-by-Step Implementation

### 1. Define the Abstract Base Class
Create an abstract base class that defines the common interface:

```python
from abc import ABC, abstractmethod
from typing import Protocol, runtime_checkable

@runtime_checkable
class YourExecutor(Protocol):
    """Minimal live execution port."""
    def execute(self, request) -> object: ...

class YourService(ABC):
    """Abstract base class defining the common interface."""
    
    @abstractmethod
    def method_one(self, param1, *, context) -> ReturnType:
        """Description of what this method does."""
        raise NotImplementedError
    
    @abstractmethod
    def method_two(self, param2) -> None:
        """Description of what this method does."""
        raise NotImplementedError
    
    # Add more abstract methods as needed
    
    @property
    @abstractmethod
    def is_configured(self) -> bool:
        """Check if the service is properly configured."""
        raise NotImplementedError
```

### 2. Implement Concrete Classes
Create concrete implementations for each variant:

```python
class FirstImplementation(YourService):
    """First concrete implementation."""
    
    def __init__(self, config, *, fallback=None):
        self._config = config
        self._fallback = fallback
        # Initialize implementation-specific resources
    
    @property
    def is_configured(self) -> bool:
        return self._config.is_valid()  # Implementation-specific check
    
    def method_one(self, param1, *, context):
        """Implementation-specific logic for method one."""
        # Implementation details
        if not self.is_configured:
            raise ConfigurationError("Service not properly configured")
        # ... implementation ...
        return result
    
    def method_two(self, param2):
        """Implementation-specific logic for method two."""
        # Implementation details
        # ... implementation ...
```

### 3. Refactor Existing Code to Depend on the Abstraction
Update existing code to depend on the abstract class rather than concrete implementations:

```python
# Before: Direct dependence on concrete implementation
class SomeClient:
    def __init__(self):
        self._service = ConcreteImplementationA(config)
    
    def do_work(self, data):
        result = self._service.method_one(data)
        # ...

# After: Dependence on abstract base class
class SomeClient:
    def __init__(self, service: YourService | None = None):
        self._service = service or self._create_default_service()
    
    def _create_default_service(self) -> YourService:
        """Create a default service for backward compatibility."""
        config = DefaultConfig()
        return FirstImplementation(config)  # or whichever is appropriate
    
    def do_work(self, data):
        result = self._service.method_one(data)
        # ...
```

### 4. Handle Configuration Properly
Use existing configuration systems to initialize implementations:

```python
def create_service_from_config(config: YourConfig) -> YourService:
    """Factory function to create service from configuration."""
    if config.service_type == "first":
        return FirstImplementation(config)
    elif config.service_type == "second":
        return SecondImplementation(config)
    else:
        raise ValueError(f"Unknown service type: {config.service_type}")
```

### 5. Maintain Backward Compatibility
When refactoring existing code:
- Provide default implementations that preserve existing behavior
- Use factory functions or dependency injection to allow injection of different implementations
- Keep existing APIs unchanged where possible
- Add new configuration options rather than changing existing ones

### 6. Write Tests
Create tests for both the abstract class and concrete implementations:

```python
def test_abstract_service_cannot_be_instantiated():
    """Test that the abstract base class cannot be instantiated directly."""
    with pytest.raises(TypeError):
        YourService()  # type: ignore

def test_first_implementation_method_one():
    """Test method one of the first implementation."""
    service = FirstImplementation(test_config)
    result = service.method_one(test_param, context=test_context)
    # Assert expected results
    assert result == expected_output

def test_service_switching():
    """Test that different implementations can be swapped."""
    first = FirstImplementation(config1)
    second = SecondImplementation(config2)
    
    client = SomeClient(service=first)
    result1 = client.do_work(data)
    
    client._service = second
    result2 = client.do_work(data)
    
    # Results may differ but both should be valid
    assert is_valid_result(result1)
    assert is_valid_result(result2)
```

## Pitfalls & How to Avoid Them

### Pitfall: Leaky Abstractions
**Problem:** The abstract interface becomes too specific to one implementation, forcing others to implement irrelevant methods or return dummy values.

**Solution:** 
- Keep the interface focused on what all implementations truly need to do
- Use optional parameters or separate interfaces for implementation-specific features
- Consider using the Interface Segregation Principle: create smaller, more specific interfaces

### Pitfall: Anemic Domain Model
**Problem:** The abstract class becomes just a collection of getters and setters with no real behavior.

**Solution:**
- Include meaningful behavior in the abstract class where appropriate
- Use template method patterns for algorithms with varying steps
- Put shared validation or preprocessing in the abstract class

### Pitfall: Configuration Complexity
**Problem:** Managing different configuration requirements for each implementation becomes complex.

**Solution:**
- Use a common configuration base with implementation-specific extensions
- Implement validation at the configuration level
- Provide clear error messages when configuration is incomplete or invalid
- Use configuration factories or builders

### Pitfall: Testing Complexity
**Problem:** Testing becomes difficult because implementations have external dependencies.

**Solution:**
- Design implementations to accept dependencies via constructor injection
- Use mock objects or test doubles for external dependencies
- Create test-specific implementations that simulate behavior
- Test at the abstraction level when possible

## Verification

After implementing this pattern, verify:
- [ ] The abstract base class cannot be instantiated directly
- [ ] All concrete implementations properly implement all abstract methods
- [ ] Existing code continues to work with the new abstraction (backward compatibility)
- [ ] New implementations can be added without modifying existing code
- [ ] Configuration properly initializes each implementation type
- [ ] Unit tests pass for all implementations
- [ ] Integration tests verify the abstraction works in context
- [ ] Performance is not significantly degraded by the abstraction layer
- [ ] Documentation clearly explains how to add new implementations

## References
- [Dependency Inversion Principle](https://en.wikipedia.org/wiki/Dependency_inversion_principle)
- [Interface Segregation Principle](https://en.wikipedia.org/wiki/Interface_segregation_principle)
- [Python ABC Documentation](https://docs.python.org/3/library/abc.html)
- [Protocol and Structural Subtyping (PEP 544)](https://peps.python.org/pep-0544/)

## Andromeda-Specific Notes

In the Andromeda codebase:
- Venue implementations live in `notebooks/andromeda/venue/<venue_name>/`
- The abstract Venue class is in `notebooks/andromeda/venue/venue.py`
- Configuration is handled via `VenueConfig` in `notebooks/andromeda/venue/config.py`
- Dry-run guards are in `notebooks/andromeda/venue/guards.py`
- Existing implementations (HL, IBKR, CME) follow this pattern
- BotRunner was refactored to depend on the abstract Venue class

### Implementation Insights from Andromeda Venue Refactor

1. **Start with One Implementation**: Begin by implementing one concrete venue (Hyperliquid) completely before creating others. This ensures your abstract interface is correct and complete.

2. **Leverage Existing Code**: Rather than rewriting from scratch, adapt existing implementation code to fit the new interface. The HyperliquidVenue class delegated to the existing `HlOrderSubmit` logic where possible.

3. **Configuration Handling**: Each venue implementation should handle its own configuration loading and validation, using the existing `VenueConfig` system.

4. **Dry-run Consistency**: Reuse existing dry-run guards like `forbid_live_under_dry_run` to maintain consistency with the rest of the codebase.

5. **Backward Compatibility Strategy**: When refactoring existing consumers (like BotRunner), provide a default implementation that preserves existing behavior when no explicit venue is configured.

6. **Error Handling**: Use existing error types (like `VenueConfigError`) rather than creating new ones to maintain consistency.

7. **Testing Approach**: Create test implementations that inherit from the abstract class to verify the interface works correctly before implementing the real versions.

8. **Gradual Migration**: Consider keeping the old implementation available during transition period, then remove it once all consumers have been migrated to the new abstraction.