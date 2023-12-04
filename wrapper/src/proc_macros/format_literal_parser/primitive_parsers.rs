use nom::bytes::complete::{take_while1, take_while_m_n};
use nom::character::{is_alphabetic, is_alphanumeric, is_hex_digit};
use nom::combinator::map;
use nom::sequence::tuple;
use nom::IResult;

pub fn parse_digits(input: &str) -> IResult<&str, String> {
    map(take_while1(|c: char| c.is_numeric()), |s: &str| {
        s.to_string()
    })(input)
}

pub fn is_hex_char(input: char) -> bool {
    u8::try_from(input).map(is_hex_digit).unwrap_or(false)
}

pub fn is_snake_case_char(input: char) -> bool {
    u8::try_from(input)
        .map(|u| is_alphanumeric(u) || u == b'_')
        .unwrap_or(false)
}

pub fn is_snake_case_beginning_char(input: char) -> bool {
    u8::try_from(input)
        .map(|u| is_alphabetic(u) || u == b'_')
        .unwrap_or(false)
}

pub fn parse_snake_case_label(input: &str) -> IResult<&str, String> {
    map(
        tuple((
            take_while_m_n(1, 1, is_snake_case_beginning_char),
            take_while1(is_snake_case_char),
        )),
        |(a, b)| format!("{a}{b}"),
    )(input)
}
