use clap::Parser;
use opa_wasm::Runtime;
use serde_json::{json, Value};
use std::fs::File;
use std::io::Write;
use std::path::PathBuf;
use wasmtime::{Config, Engine, Module, Store};

/// A policy evaluator wrapping the OPA policy %rego% with entrypoint %entrypoint%
#[derive(Parser)]
#[command(author, about, long_about = None)]
struct Cli {
    /// Policy data object
    #[arg(short, long)]
    data: Option<String>,

    /// Path to policy data JSON object
    #[arg(short, long)]
    data_path: Option<PathBuf>,

    /// Policy input object
    #[arg(short, long)]
    input: Option<String>,

    /// Path to policy input JSON object
    #[arg(short, long)]
    input_path: Option<PathBuf>,

    /// Result JSON output path
    #[arg(short, long)]
    output: Option<PathBuf>,
}

impl Cli {
    fn validate(&self) -> Result<(), EvalError> {
        if self.input.is_some() && self.input_path.is_some() {
            return Err(EvalError::ConfigError(String::from(
                "you can only specify --input or --input-path, not both",
            )));
        }

        if self.data.is_some() && self.data_path.is_some() {
            return Err(EvalError::ConfigError(String::from(
                "you can only specify --data or --data-path, not both",
            )));
        }

        Ok(())
    }
}

#[derive(Debug, thiserror::Error)]
enum EvalError {
    #[error("config error: {0}")]
    ConfigError(String),

    #[error("io error: {0}")]
    Io(#[from] std::io::Error),

    #[error("error: {0}")]
    Any(#[from] anyhow::Error),

    #[error("json error: {0}")]
    Json(#[from] serde_json::Error),
}

fn get_json(s: Option<String>, p: Option<PathBuf>) -> Result<Value, EvalError> {
    let js = if let Some(s) = s {
        serde_json::from_str(&s)?
    } else if let Some(p) = p {
        let s = std::fs::read_to_string(p)?;
        serde_json::from_str(&s)?
    } else {
        json!({})
    };
    Ok(js)
}

#[tokio::main]
async fn main() -> Result<(), EvalError> {
    let args = Cli::parse();
    args.validate()?;

    let mut config = Config::new();
    config.async_support(true);
    let engine = Engine::new(&config)?;
    let module = tokio::fs::read("%policy%").await?;
    let module = Module::new(&engine, module)?;
    let mut store = Store::new(&engine, ());
    let data = get_json(args.data, args.data_path)?;
    let input = get_json(args.input, args.input_path)?;
    let runtime = Runtime::new(&mut store, &module).await?;
    let policy = runtime.with_data(&mut store, &data).await?;
    let value: serde_json::Value = policy.evaluate(&mut store, "%entrypoint%", &input).await?;
    let output_json = serde_json::to_string_pretty(&value)?;

    if let Some(output) = args.output {
        let path = output.to_str().unwrap();
        let mut file = File::create(path)?;
        file.write_all(output_json.as_bytes())?;
    } else {
        std::io::stdout().write_all(output_json.as_bytes())?;
    }

    Ok(())
}
