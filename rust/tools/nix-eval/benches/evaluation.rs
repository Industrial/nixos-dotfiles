//! Benchmark suite for nix-eval
//!
//! Run benchmarks with: `cargo bench`

use criterion::{Criterion, black_box, criterion_group, criterion_main};
use nix_eval::Evaluator;

fn bench_evaluate_integer(c: &mut Criterion) {
    let evaluator = Evaluator::new();
    c.bench_function("evaluate_integer", |b| {
        b.iter(|| evaluator.evaluate(black_box("42")))
    });
}

fn bench_evaluate_string(c: &mut Criterion) {
    let evaluator = Evaluator::new();
    c.bench_function("evaluate_string", |b| {
        b.iter(|| evaluator.evaluate(black_box(r#""hello world""#)))
    });
}

fn bench_evaluate_list(c: &mut Criterion) {
    let evaluator = Evaluator::new();
    c.bench_function("evaluate_list", |b| {
        b.iter(|| evaluator.evaluate(black_box("[1 2 3 4 5]")))
    });
}

fn bench_evaluate_nested_list(c: &mut Criterion) {
    let evaluator = Evaluator::new();
    c.bench_function("evaluate_nested_list", |b| {
        b.iter(|| evaluator.evaluate(black_box("[[1 2] [3 4] [5 6]]")))
    });
}

fn bench_evaluate_attribute_set(c: &mut Criterion) {
    let evaluator = Evaluator::new();
    c.bench_function("evaluate_attribute_set", |b| {
        b.iter(|| evaluator.evaluate(black_box("{ foo = 1; bar = 2; baz = 3; }")))
    });
}

fn bench_evaluate_nested_attribute_set(c: &mut Criterion) {
    let evaluator = Evaluator::new();
    c.bench_function("evaluate_nested_attribute_set", |b| {
        b.iter(|| {
            evaluator.evaluate(black_box(
                "{ outer = { inner = 42; }; another = { value = \"test\"; }; }",
            ))
        })
    });
}

fn bench_evaluate_complex_expression(c: &mut Criterion) {
    let evaluator = Evaluator::new();
    c.bench_function("evaluate_complex_expression", |b| {
        b.iter(|| {
            evaluator.evaluate(black_box(
                r#"{ 
                    name = "test"; 
                    items = [1 2 3 4 5]; 
                    config = { enabled = true; value = 42; }; 
                }"#,
            ))
        })
    });
}

fn bench_variable_resolution(c: &mut Criterion) {
    use nix_eval::VariableScope;
    use std::collections::HashMap;

    let mut evaluator = Evaluator::new();
    let mut scope: VariableScope = HashMap::new();
    scope.insert("x".to_string(), nix_eval::NixValue::Integer(42));
    scope.insert(
        "y".to_string(),
        nix_eval::NixValue::String("hello".to_string()),
    );
    evaluator.set_scope(scope);

    c.bench_function("variable_resolution", |b| {
        b.iter(|| evaluator.evaluate(black_box("x")))
    });
}

criterion_group!(
    benches,
    bench_evaluate_integer,
    bench_evaluate_string,
    bench_evaluate_list,
    bench_evaluate_nested_list,
    bench_evaluate_attribute_set,
    bench_evaluate_nested_attribute_set,
    bench_evaluate_complex_expression,
    bench_variable_resolution
);
criterion_main!(benches);
