use std::{
    fmt::Display,
    io::{stdin, Stdin},
};

use paris::Logger;

pub use proc_macros::{confirm, error, info, log, success, warn};

// macro_rules! convert {
//     (~$value:expr) => {
//         format!("{:?}", $value)
//     };
//     ($value:expr) => {
//         ($value).to_string()
//     };
// }

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
            "clear_all" => "".to_string(),
            "clear_bg" => "".to_string(),
            "clear_fg" => "".to_string(),

            "custom_destructive" => "".to_string(),
            "custom_variable" => "".to_string(),
            "custom_path" => "".to_string(),
            _ => "".to_string(),
        }
    }
}

pub fn try_enable_stdout_color() -> bool {
    enable_ansi_support::enable_ansi_support().is_ok()
}
