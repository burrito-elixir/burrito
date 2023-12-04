use proc_macro::{Delimiter, Group, Ident, Literal, Punct, Spacing, Span, TokenStream, TokenTree};

pub fn string_literal(str: &str) -> TokenTree {
    let str = Literal::string(str);
    TokenTree::Literal(str)
}

pub fn ident(str: &str) -> TokenTree {
    TokenTree::Ident(Ident::new(str, Span::mixed_site()))
}

pub fn punct(ch: char) -> TokenTree {
    let p = Punct::new(ch, Spacing::Alone);
    TokenTree::Punct(p)
}

pub fn parens(tree: Vec<TokenTree>) -> TokenTree {
    let group = Group::new(Delimiter::Parenthesis, TokenStream::from_iter(tree));
    TokenTree::Group(group)
}

pub fn closure(tree: Vec<TokenTree>) -> TokenTree {
    let group = Group::new(Delimiter::Brace, TokenStream::from_iter(tree));
    TokenTree::Group(group)
}

pub fn group(tree: Vec<TokenTree>) -> TokenTree {
    let group = Group::new(Delimiter::None, TokenStream::from_iter(tree));
    TokenTree::Group(group)
}

pub fn is_comma(tree: &TokenTree) -> bool {
    matches!(tree, TokenTree::Punct(p) if p.as_char() == ',')
}

pub fn is_equal_sign(tree: &TokenTree) -> bool {
    matches!(tree, TokenTree::Punct(p) if p.as_char() == '=')
}

pub fn get_identifier(tree: &TokenTree) -> Option<String> {
    match tree {
        TokenTree::Ident(i) => Some(i.to_string()),
        _ => None,
    }
}
