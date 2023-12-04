use std::{
    fmt::Display,
    io::{stdin, Stdin},
};

/* This module defines a trait for handling user input and output. The IO
   implementation is dependency injected at runtime, allowing for custom output
   drains, conditional styling, and testing capabilities.
*/

use paris::Logger;

pub use proc_macros::{confirm, error, info, loading, log, success, warn};

pub trait IO {
    fn read_line(&mut self) -> String
    where
        Self: Sized;

    fn done(&mut self) -> &mut Self
    where
        Self: Sized;

    fn loading<A: Display>(&mut self, msg: A) -> &mut Self
    where
        Self: Sized;

    fn is_loading(&self) -> bool
    where
        Self: Sized;

    fn log<A: Display>(&mut self, str: A) -> &mut Self
    where
        Self: Sized;

    fn warn<A: Display>(&mut self, str: A) -> &mut Self
    where
        Self: Sized;

    fn error<A: Display>(&mut self, str: A) -> &mut Self
    where
        Self: Sized;

    fn success<A: Display>(&mut self, str: A) -> &mut Self
    where
        Self: Sized;

    fn info<A: Display>(&mut self, str: A) -> &mut Self
    where
        Self: Sized;

    fn indent(&mut self, amount: usize) -> &mut Self
    where
        Self: Sized;

    fn newline(&mut self, amount: usize) -> &mut Self
    where
        Self: Sized;

    fn confirm<A: Display>(&mut self, message: A) -> bool
    where
        Self: Sized,
    {
        log!(self, "{} <choice>[y/N]</>", message);

        let response = self.read_line();

        response == "y\n" || response == "Y\n"
    }

    fn render_style(&mut self, name: &str) -> String
    where
        Self: Sized;
}

pub struct NoIO {}

impl IO for NoIO {
    fn read_line(&mut self) -> String {
        String::new()
    }

    fn loading<A: Display>(&mut self, _: A) -> &mut Self {
        self
    }

    fn is_loading(&self) -> bool {
        false
    }

    fn done(&mut self) -> &mut Self {
        self
    }

    fn log<A: Display>(&mut self, _: A) -> &mut Self {
        self
    }

    fn warn<A: Display>(&mut self, _: A) -> &mut Self {
        self
    }

    fn error<A: Display>(&mut self, _: A) -> &mut Self {
        self
    }

    fn success<A: Display>(&mut self, _: A) -> &mut Self {
        self
    }

    fn info<A: Display>(&mut self, _: A) -> &mut Self {
        self
    }

    fn indent(&mut self, _: usize) -> &mut Self {
        self
    }

    fn newline(&mut self, _: usize) -> &mut Self {
        self
    }

    fn render_style(&mut self, _name: &str) -> String {
        "".to_string()
    }
}

pub struct StandardIO<'a> {
    output: Logger<'a>,
    input: Stdin,
    loading: bool,
    color: bool,
}

pub struct StandardIOConfig {
    pub color: bool,
}

impl<'a> StandardIO<'a> {
    pub const DEFAULT: StandardIOConfig = StandardIOConfig { color: false };

    pub fn new(args: StandardIOConfig) -> Self {
        let logger: Logger<'a> = Logger::new();

        Self {
            output: logger,
            input: stdin(),
            loading: false,
            color: args.color,
        }
    }
}

impl IO for StandardIO<'_> {
    fn read_line(&mut self) -> String {
        let mut buffer = String::new();
        let _ = self.input.read_line(&mut buffer);
        buffer
    }

    fn loading<A: Display>(&mut self, message: A) -> &mut Self {
        self.loading = true;
        self.output.loading(message);
        self
    }

    fn is_loading(&self) -> bool {
        self.loading
    }

    fn done(&mut self) -> &mut Self {
        self.output.done();
        self.loading = false;
        self
    }

    fn log<A: Display>(&mut self, message: A) -> &mut Self {
        self.output.log(message);
        self
    }

    fn error<A: Display>(&mut self, message: A) -> &mut Self {
        self.output.error(message);
        self
    }

    fn warn<A: Display>(&mut self, message: A) -> &mut Self {
        self.output.warn(message);
        self
    }

    fn success<A: Display>(&mut self, message: A) -> &mut Self {
        self.output.success(message);
        self
    }

    fn info<A: Display>(&mut self, message: A) -> &mut Self {
        self.output.info(message);
        self
    }

    fn indent(&mut self, amount: usize) -> &mut Self {
        self.output.indent(amount);
        self
    }

    fn newline(&mut self, amount: usize) -> &mut Self {
        self.output.newline(amount);
        self
    }

    fn render_style(&mut self, name: &str) -> String {
        if !self.color {
            return "".to_string();
        }

        match name {
            "clear_all" => "\x1b[m".to_string(),
            "clear_bg" => "\x1b[49m".to_string(),
            "clear_fg" => "\x1b[39m".to_string(),

            "custom_destructive" => "\x1b[0;31m".to_string(),
            "custom_variable" => "\x1b[1;34m".to_string(),
            "custom_path" => "\x1b[0;36m".to_string(),
            "custom_choice" => "\x1b[0;33m".to_string(),
            _ => "".to_string(),
        }
    }
}

pub fn try_enable_stdout_color() -> bool {
    enable_ansi_support::enable_ansi_support().is_ok()
}
