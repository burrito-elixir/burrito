use std::collections::HashSet;
use std::fmt;

use nom::branch::alt;
use nom::bytes::complete::{tag, take_while1};
use nom::character::complete::{char, none_of, one_of};
use nom::combinator::{map, opt, success};
use nom::sequence::{delimited, preceded, terminated, tuple};
use nom::IResult;

use super::primitive_parsers::parse_digits;

#[derive(Clone, Debug)]
enum Precision {
    PrecisionCount(Count),
    PrecisionNext,
}

#[derive(Clone, Debug)]
enum DebugType {
    DebugDefault,
    DebugLowercaseHex,
    DebugUppercaseHex,
}

#[derive(Clone, Debug)]
enum FormatType {
    FormatEmpty,
    FormatDebug(DebugType),
    FormatIdentifier(String),
}

#[derive(Clone, Debug)]
struct Align {
    fill: Option<char>,
    position: char,
}

#[derive(Clone, Debug)]
enum Argument {
    ArgumentIdentifier(String),
    ArgumentInteger(String),
}

#[derive(Clone, Debug)]
struct Parameter(String);

#[derive(Clone, Debug)]
enum Count {
    CountParameter(Parameter),
    CountInteger(String),
}

#[derive(Clone, Debug)]
struct FormatSpec {
    align: Option<Align>,
    sign: Option<char>,
    pretty: bool,
    zero_padded: bool,
    width: Option<Count>,
    precision: Option<Precision>,
    format_type: FormatType,
}

#[derive(Clone, Debug)]
pub struct Format {
    argument: Option<Argument>,
    format_spec: Option<FormatSpec>,
}

pub trait VarCollector {
    fn collect_variables(&self) -> HashSet<String>;
}

impl VarCollector for Precision {
    fn collect_variables(&self) -> HashSet<String> {
        match self {
            Precision::PrecisionCount(c) => c.collect_variables(),
            _ => HashSet::new(),
        }
    }
}

impl VarCollector for Argument {
    fn collect_variables(&self) -> HashSet<String> {
        match self {
            Argument::ArgumentIdentifier(s) => [s.clone()].into(),
            _ => HashSet::new(),
        }
    }
}

impl VarCollector for Parameter {
    fn collect_variables(&self) -> HashSet<String> {
        [self.0.clone()].into()
    }
}

impl VarCollector for Count {
    fn collect_variables(&self) -> HashSet<String> {
        match self {
            Count::CountParameter(p) => p.collect_variables(),
            _ => HashSet::new(),
        }
    }
}

impl VarCollector for FormatSpec {
    fn collect_variables(&self) -> HashSet<String> {
        let mut result = HashSet::new();

        if let Some(ref count) = self.width {
            result.extend(count.collect_variables());
        }

        if let Some(ref precision) = self.precision {
            result.extend(precision.collect_variables());
        }

        result
    }
}

impl VarCollector for Format {
    fn collect_variables(&self) -> HashSet<String> {
        let mut results = HashSet::new();

        if let Some(ref a) = self.argument {
            results.extend(a.collect_variables())
        }

        if let Some(ref fs) = self.format_spec {
            results.extend(fs.collect_variables())
        }

        results
    }
}

impl fmt::Display for Precision {
    fn fmt(&self, f: &mut fmt::Formatter) -> fmt::Result {
        match self {
            Precision::PrecisionCount(c) => write!(f, "{}", c),
            Precision::PrecisionNext => write!(f, "*"),
        }
    }
}

impl fmt::Display for DebugType {
    fn fmt(&self, f: &mut fmt::Formatter) -> fmt::Result {
        match self {
            DebugType::DebugLowercaseHex => write!(f, "x?"),
            DebugType::DebugUppercaseHex => write!(f, "X?"),
            DebugType::DebugDefault => write!(f, "?"),
        }
    }
}

impl fmt::Display for FormatType {
    fn fmt(&self, f: &mut fmt::Formatter) -> fmt::Result {
        match self {
            FormatType::FormatEmpty => Ok(()),
            FormatType::FormatDebug(d) => write!(f, "{d}"),
            FormatType::FormatIdentifier(s) => write!(f, "{s}"),
        }
    }
}

impl fmt::Display for Align {
    fn fmt(&self, f: &mut fmt::Formatter) -> fmt::Result {
        if let Some(c) = self.fill {
            write!(f, "{c}")?
        }

        write!(f, "{}", self.position)
    }
}

impl fmt::Display for Argument {
    fn fmt(&self, f: &mut fmt::Formatter) -> fmt::Result {
        match self {
            Argument::ArgumentIdentifier(s) => write!(f, "{s}"),
            Argument::ArgumentInteger(s) => write!(f, "{s}"),
        }
    }
}

impl fmt::Display for Parameter {
    fn fmt(&self, f: &mut fmt::Formatter) -> fmt::Result {
        write!(f, "{}$", self.0)
    }
}

impl fmt::Display for Count {
    fn fmt(&self, f: &mut fmt::Formatter) -> fmt::Result {
        match self {
            Count::CountParameter(p) => write!(f, "{}", p),
            Count::CountInteger(s) => write!(f, "{}", s),
        }
    }
}

impl fmt::Display for FormatSpec {
    fn fmt(&self, f: &mut fmt::Formatter) -> fmt::Result {
        if let Some(ref align) = self.align {
            write!(f, "{align}")?
        }

        if let Some(sign) = self.sign {
            write!(f, "{sign}")?
        }

        if self.pretty {
            write!(f, "#")?
        }

        if self.zero_padded {
            write!(f, "0")?
        }

        if let Some(ref width) = self.width {
            write!(f, "{width}")?
        }

        if let Some(ref precision) = self.precision {
            write!(f, ".{precision}")?
        }

        write!(f, "{}", self.format_type)
    }
}

impl fmt::Display for Format {
    fn fmt(&self, f: &mut fmt::Formatter) -> fmt::Result {
        write!(f, "{{")?;

        if let Some(ref a) = self.argument {
            write!(f, "{a}")?
        }

        if let Some(ref fs) = self.format_spec {
            write!(f, ":{fs}")?
        }

        write!(f, "}}")
    }
}

fn parse_debug(input: &str) -> IResult<&str, DebugType> {
    let default = map(char('?'), |_| DebugType::DebugDefault);
    let lowercase_hex = map(tag("x?"), |_| DebugType::DebugLowercaseHex);
    let uppercase_hex = map(tag("X?"), |_| DebugType::DebugUppercaseHex);

    alt((default, lowercase_hex, uppercase_hex))(input)
}

const INVALID_LITS: [char; 10] = ['$', '}', '"', '{', ' ', '=', ';', '(', ')', ':'];
fn is_literal_char(c: char) -> bool {
    !INVALID_LITS.contains(&c)
}

fn parse_identifier(input: &str) -> IResult<&str, String> {
    map(take_while1(is_literal_char), |s: &str| s.to_string())(input)
}

fn parse_format_type(input: &str) -> IResult<&str, FormatType> {
    let debug = map(parse_debug, |d| FormatType::FormatDebug(d));
    let identifier = map(parse_identifier, |s| FormatType::FormatIdentifier(s));
    let empty = map(success(()), |_| FormatType::FormatEmpty);

    alt((debug, identifier, empty))(input)
}

fn parse_align(input: &str) -> IResult<&str, Align> {
    map(
        tuple((opt(none_of("}")), one_of("<^>"))),
        |(fill, position)| Align { fill, position },
    )(input)
}

fn parse_sign(input: &str) -> IResult<&str, char> {
    one_of("+-")(input)
}

fn parse_pretty(input: &str) -> IResult<&str, bool> {
    map(opt(char('#')), |c| c.is_some())(input)
}

fn parse_padded(input: &str) -> IResult<&str, bool> {
    map(opt(char('0')), |c| c.is_some())(input)
}

fn parse_argument(input: &str) -> IResult<&str, Argument> {
    let arg_int = map(parse_digits, |s: String| Argument::ArgumentInteger(s));

    let arg_idt = map(parse_identifier, |s: String| {
        Argument::ArgumentIdentifier(s)
    });

    alt((arg_int, arg_idt))(input)
}

fn parse_parameter(input: &str) -> IResult<&str, Parameter> {
    map(terminated(parse_identifier, char('$')), |s| Parameter(s))(input)
}

fn parse_format_spec(input: &str) -> IResult<&str, FormatSpec> {
    map(
        tuple((
            opt(parse_align),
            opt(parse_sign),
            parse_pretty,
            parse_padded,
            opt(parse_width),
            opt(parse_precision),
            parse_format_type,
        )),
        |(align, sign, pretty, zero_padded, width, precision, format_type)| FormatSpec {
            align,
            sign,
            pretty,
            zero_padded,
            width,
            precision,
            format_type,
        },
    )(input)
}

fn parse_width(input: &str) -> IResult<&str, Count> {
    parse_count(input)
}

fn parse_precision(input: &str) -> IResult<&str, Precision> {
    let count = map(parse_count, |c| Precision::PrecisionCount(c));
    let next = map(char('*'), |_| Precision::PrecisionNext);

    preceded(char('.'), alt((next, count)))(input)
}

fn parse_count(input: &str) -> IResult<&str, Count> {
    let parameter = map(parse_parameter, |a| Count::CountParameter(a));
    let integer = map(parse_digits, |s| Count::CountInteger(s));

    alt((integer, parameter))(input)
}

pub fn parse_template(input: &str) -> IResult<&str, Format> {
    let format_spec_chunk = preceded(char(':'), parse_format_spec);

    let parser = delimited(
        char('{'),
        tuple((opt(parse_argument), opt(format_spec_chunk))),
        char('}'),
    );

    map(parser, |(argument, format_spec)| Format {
        argument,
        format_spec,
    })(input)
}

pub fn parse_template_escape(input: &str) -> IResult<&str, String> {
    map(tag("{{"), |s: &str| s.to_string())(input)
}
