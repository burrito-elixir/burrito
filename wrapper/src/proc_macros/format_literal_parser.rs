pub mod primitive_parsers;

use std::fmt;

use nom::branch::alt;
use nom::bytes::complete::{is_not, tag, take_while_m_n};
use nom::character::complete::{char, one_of};
use nom::combinator::{eof, map};
use nom::multi::many0;
use nom::sequence::{delimited, preceded, terminated};
use nom::IResult;

use primitive_parsers::{is_hex_char, parse_snake_case_label};

use thiserror::Error;

#[derive(Error, Debug)]
pub enum FormatLiteralParserError {
    #[error("Invalid escape sequence")]
    InvalidEscape,

    #[error("Second argument must be a string literal")]
    MissingLiteral,
}

#[derive(Clone, Debug)]
pub enum StyleTag {
    StyleNamed(String),
    StyleClearAll,
    StyleClearBg,
    StyleClearFg,
}

impl StyleTag {
    pub fn identifier(&self) -> String {
        match self {
            StyleTag::StyleNamed(s) => format!("__macro_style_custom_{s}__"),
            StyleTag::StyleClearAll => format!("__macro_style_clear_all__"),
            StyleTag::StyleClearBg => format!("__macro_style_clear_bg__"),
            StyleTag::StyleClearFg => format!("__macro_style_clear_fg__"),
        }
    }

    pub fn literal(&self) -> String {
        match self {
            StyleTag::StyleNamed(s) => format!("custom_{s}"),
            StyleTag::StyleClearAll => format!("clear_all"),
            StyleTag::StyleClearBg => format!("clear_bg"),
            StyleTag::StyleClearFg => format!("clear_fg"),
        }
    }
}

impl fmt::Display for StyleTag {
    fn fmt(&self, f: &mut fmt::Formatter) -> fmt::Result {
        write!(f, "{}", self.identifier())
    }
}

#[derive(Clone, Debug)]
enum FormatLiteralSegment {
    EscapeSegment(String),
    StyleSegment(StyleTag),
    TextSegment(String),
}

impl fmt::Display for FormatLiteralSegment {
    fn fmt(&self, f: &mut fmt::Formatter) -> fmt::Result {
        match self {
            FormatLiteralSegment::EscapeSegment(s) => write!(f, "{s}"),
            FormatLiteralSegment::StyleSegment(t) => write!(f, "{{{t}}}"),
            FormatLiteralSegment::TextSegment(s) => write!(f, "{s}"),
        }
    }
}

#[derive(Clone)]
pub struct FormatLiteral(Vec<FormatLiteralSegment>);

impl FormatLiteral {
    pub fn style_tags(&self) -> Vec<StyleTag> {
        self.0
            .clone()
            .into_iter()
            .filter_map(|x| match x {
                FormatLiteralSegment::StyleSegment(t) => Some(t),
                _ => None,
            })
            .collect()
    }
}

impl fmt::Display for FormatLiteral {
    fn fmt(&self, f: &mut fmt::Formatter) -> fmt::Result {
        write!(
            f,
            "{}",
            self.0
                .clone()
                .into_iter()
                .map(|x| x.to_string())
                .collect::<String>()
        )
    }
}

impl fmt::Debug for FormatLiteral {
    fn fmt(&self, f: &mut fmt::Formatter) -> fmt::Result {
        write!(f, "FormatLiteral{:?}", self.0)
    }
}

// SINGLE_ESCAPE = "n" | "r" | "t" | "\" | "0" | %x22
fn parse_single_escape(input: &str) -> IResult<&str, FormatLiteralSegment> {
    map(one_of("nrt\\0'\""), |x| {
        let code = match x {
            'n' => '\n',
            'r' => '\r',
            't' => '\t',
            '\\' => '\\',
            '0' => '\0',
            '"' => '"',
            _ => panic!("Unexpected escape sequence - this should be impossible"),
        };

        FormatLiteralSegment::EscapeSegment(code.to_string())
    })(input)
}

// ASCII_ESCAPE = "x" 2HEX_DIGIT
fn parse_ascii_escape(input: &str) -> IResult<&str, FormatLiteralSegment> {
    map(
        preceded(char('x'), take_while_m_n(2, 2, is_hex_char)),
        |a| FormatLiteralSegment::EscapeSegment(format!("x{a}")),
    )(input)
}

// UNICODE_ESCAPE = "u{" 1*6HEX_DIGIT "}"
fn parse_unicode_escape(input: &str) -> IResult<&str, FormatLiteralSegment> {
    map(
        preceded(
            char('u'),
            delimited(char('{'), take_while_m_n(1, 6, is_hex_char), char('}')),
        ),
        |a| FormatLiteralSegment::EscapeSegment(format!("u{{{a}}}")),
    )(input)
}

// COLOR_TAG_ESCAPE = "<"
fn parse_color_tag_escape(input: &str) -> IResult<&str, FormatLiteralSegment> {
    map(tag("<"), |s: &str| {
        FormatLiteralSegment::TextSegment(s.to_string())
    })(input)
}

// ESCAPE_SEGMENT = "\" ( SINGLE_ESCAPE | ASCII_ESCAPE | UNICODE_ESCAPE | COLOR_TAG_ESCAPE )
fn parse_backslash_escape_segment(input: &str) -> IResult<&str, FormatLiteralSegment> {
    preceded(
        char('\\'),
        alt((
            parse_single_escape,
            parse_ascii_escape,
            parse_unicode_escape,
            parse_color_tag_escape,
        )),
    )(input)
}

// Parses anything that is not a color tag or an escape sequence.
fn parse_misc_segment(input: &str) -> IResult<&str, FormatLiteralSegment> {
    map(is_not("\\<\""), |s: &str| {
        FormatLiteralSegment::TextSegment(s.to_string())
    })(input)
}

// COLOR_TAG_SEGMENT = "<" ( "/" | "//" | "///" | SNAKE_CASE_START SNAKE_CASE_CHAR* ) ">"
fn parse_color_tag_segment(input: &str) -> IResult<&str, FormatLiteralSegment> {
    let color_type = alt((
        map(tag("/"), |_c| StyleTag::StyleClearAll),
        map(tag("//"), |_c| StyleTag::StyleClearFg),
        map(tag("///"), |_c| StyleTag::StyleClearBg),
        map(parse_snake_case_label, |c: String| StyleTag::StyleNamed(c)),
    ));

    map(delimited(char('<'), color_type, char('>')), |s| {
        FormatLiteralSegment::StyleSegment(s)
    })(input)
}

// FORMAT_LITERAL = *( COLOR_TAG_SEGMENT | ESCAPE_SEGMENT | MISC_SEGMENT )
pub fn parse_format_literal(input: &str) -> Result<FormatLiteral, FormatLiteralParserError> {
    let parse_inner_content = many0(alt((
        parse_color_tag_segment,
        parse_backslash_escape_segment,
        parse_misc_segment,
    )));

    let parse_string_literal = delimited(char('"'), parse_inner_content, char('"'));

    let content = map(parse_string_literal, |ls| FormatLiteral(ls));

    let result = terminated(content, eof)(input);

    if let Ok((_, result)) = result {
        Ok(result)
    } else {
        Err(FormatLiteralParserError::InvalidEscape)
    }
}
