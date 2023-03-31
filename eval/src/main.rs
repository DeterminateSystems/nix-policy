use std::collections::HashMap;

use anyhow::Result;
use wasmtime::{Config, Engine, Module, Store};

use opa_wasm::Runtime;

#[tokio::main]
async fn main() -> Result<()> {
    // Configure the WASM runtime
    let mut config = Config::new();
    config.async_support(true);

    let engine = Engine::new(&config)?;

    // Load the policy WASM module
    let module = tokio::fs::read("policy.wasm").await?;
    let module = Module::new(&engine, module)?;

    // Create a store which will hold the module instance
    let mut store = Store::new(&engine, ());

    let data = HashMap::from([("hello", "world")]);
    let input = HashMap::from([("message", "hello")]);

    // Instantiate the module
    let runtime = Runtime::new(&mut store, &module).await?;

    let policy = runtime.with_data(&mut store, &data).await?;

    // Evaluate the policy
    let res: serde_json::Value = policy.evaluate(&mut store, "verify/allow", &input).await?;

    println!("{}", res);

    Ok(())
}
