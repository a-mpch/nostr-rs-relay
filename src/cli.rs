use clap::Parser;

#[derive(Parser)]
#[command(about = "A nostr relay written in Rust", author = env!("CARGO_PKG_AUTHORS"), version = env!("CARGO_PKG_VERSION"))]
pub struct CLIArgs {
    #[arg(
        short,
        long,
        help = "Use the <directory> as the location of the database",
        required = false
    )]
    pub db: Option<String>,
    #[arg(
        short,
        long,
        help = "Use the <file name> as the location of the config file",
        required = false
    )]
    pub config: Option<String>,
    #[arg(
        long,
        help = "Comma-separated list of pubkeys allowed to use /lexe endpoint",
        required = false,
        value_delimiter = ','
    )]
    pub lexe_pubkeys: Option<Vec<String>>,
}
