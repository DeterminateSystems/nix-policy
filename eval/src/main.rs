use anyhow::Result;
use clap::Parser;
use opa_wasm::Runtime;
use serde_json::json;
use wasmtime::{Config, Engine, Module, Store};

/// A policy evaluator wrapping the OPA policy %rego% with entrypoint %entrypoint%
#[derive(Parser)]
#[command(author, version, about, long_about = None)]
struct Cli {
    /// Policy data object
    #[arg(short, long)]
    data: Option<String>,

    /// Policy input object
    #[arg(short, long)]
    input: Option<String>,
}

#[tokio::main]
async fn main() -> Result<()> {
    let args = Cli::parse();
    let entrypoint = "%entrypoint%";

    let mut config = Config::new();
    config.async_support(true);
    let engine = Engine::new(&config)?;
    let module = tokio::fs::read("%policy%").await?;
    let module = Module::new(&engine, module)?;
    let mut store = Store::new(&engine, ());

    // Instantiate the module
    let runtime = Runtime::new(&mut store, &module).await?;

    let data = if let Some(data) = args.data {
        serde_json::from_str(&data)?
    } else {
        json!({})
    };

    let policy = runtime.with_data(&mut store, &data).await?;

    let input = if let Some(input) = args.input {
        serde_json::from_str(&input)?
    } else {
        json!({})
    };

    // Evaluate the policy
    let value: serde_json::Value = policy.evaluate(&mut store, entrypoint, &input).await?;
    println!("{}", value);
    //let eval: EvalResult = serde_json::from_value(value)?;
    //println!("result: {}", eval.result);

    Ok(())
}
