use crossterm::terminal::{size, ClearType, Clear};
use crossterm::{cursor, ExecutableCommand};
use std::io::{self, Write};

fn main() -> io::Result<()> {
    // Get terminal size
    let (term_width, _) = size()?;

    // Define the current working directory (replace with actual logic to fetch CWD)
    let cwd = std::env::current_dir()
        .unwrap_or_else(|_| std::path::PathBuf::from("?"))
        .to_string_lossy()
        .to_string();

    // Define the rest of the prompt
    let user = whoami::username();
    let hostname = hostname::get()
        .unwrap_or_else(|_| "unknown".into())
        .to_string_lossy()
        .to_string();

    let prompt = format!("{user}@{hostname}: {cwd} > ");

    // Check if prompt length exceeds 50% of terminal width
    let prompt_length = prompt.chars().count();
    if prompt_length > (term_width / 2) as usize {
        // Multi-line prompt
        io::stdout()
            .execute(Clear(ClearType::All))?
            .execute(cursor::MoveTo(0, 0))?;
        println!("\n{cwd}\n> ");
    } else {
        // Single-line prompt
        io::stdout()
            .execute(Clear(ClearType::All))?
            .execute(cursor::MoveTo(0, 0))?;
        print!("{prompt}");
    }

    io::stdout().flush()?;
    Ok(())
}
