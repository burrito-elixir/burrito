mod format_literal_parser;
mod tree_building;

use proc_macro::{TokenStream, TokenTree};

use format_literal_parser::{parse_format_literal, FormatLiteralParserError};
use tree_building::{closure, group, ident, parens, punct, string_literal};

/* Formats strings with style tags, using the styles provided by
   structs implementing the trait IO.

       format_io(io, "<bold>My</> format string is number {}", 1)

    This locally calls `io.render_style("custom_bold")` and `io.render_style("clear_all")` in order
    to replace `<bold>` and `</>` with appropriate style symbols for the current IO implementation.
    This allows us to implement stylable IO streams for terminal viewing, as well as provide
    unstyled streams for testing or terminals which do not support styled text.
*/
#[proc_macro]
pub fn log(r: TokenStream) -> TokenStream {
    process_stream(r, "log").unwrap()
}

#[proc_macro]
pub fn success(r: TokenStream) -> TokenStream {
    process_stream(r, "success").unwrap()
}

#[proc_macro]
pub fn warn(r: TokenStream) -> TokenStream {
    process_stream(r, "warn").unwrap()
}

#[proc_macro]
pub fn info(r: TokenStream) -> TokenStream {
    process_stream(r, "info").unwrap()
}

#[proc_macro]
pub fn error(r: TokenStream) -> TokenStream {
    process_stream(r, "error").unwrap()
}

#[proc_macro]
pub fn confirm(r: TokenStream) -> TokenStream {
    process_stream(r, "confirm").unwrap()
}

#[proc_macro]
pub fn loading(r: TokenStream) -> TokenStream {
    process_stream(r, "loading").unwrap()
}

fn process_stream(ts: TokenStream, command: &str) -> Result<TokenStream, FormatLiteralParserError> {
    let mut items = ts.into_iter();

    // Collect all segments up until the first comma, treat these as
    // the IO instance to reference for IO operations.
    let mut io_segment: Vec<TokenTree> = Vec::new();
    while let Some(ref item) = items.next() {
        match item {
            TokenTree::Punct(p) => {
                if p.to_string().trim() == "," {
                    break;
                }

                io_segment.push(item.clone());
            }
            _ => io_segment.push(item.clone()),
        }
    }

    // Get the existing unstyled template literal
    let existing_literal = items
        .next()
        .ok_or(FormatLiteralParserError::MissingLiteral)?;

    // Parse the template literal to collect style tags
    let format_literal = parse_format_literal(existing_literal.to_string().as_str())?;
    // Serialize the format literal back into a string, replacing the style tags with
    // template variables for rendering the styles.
    let updated_literal = string_literal(format_literal.to_string().as_str());

    // Add finalized literal into call arg list for format!
    let mut format_call_args = Vec::new();
    format_call_args.push(updated_literal);

    // Collect the remaining arguments passed to the macro to splice into the format! call
    while let Some(tree) = items.next() {
        format_call_args.push(tree.clone());
    }

    let io = group(io_segment);

    /* The output of this macro is wrapped within a closure, it contains let bindings
       that hold the rendered styles, and the final formatting call which utilizes those variables.

       log!(io, "This is <mystyle>{}</>", "style")

       {
          let __macro_style_custom_mystyle__ = io.render_style("custom_mystyle");
          let __macro_style_clear_all__ = io.render_style("clear_all");
          io.log(
            format!(
              "This is {__macro_style_custom_mystyle__}{}{__macro_style_clear_all__}",
              "style",
              __macro_style_custom_mystyle__ = __macro_style_custom_mystyle__,
              __macro_style_clear_all__ = __macro_style_clear_all__
            )
          )
       }
    */
    let mut closure_items = vec![];
    for style_tag in format_literal.style_tags() {
        format_call_args.push(group(vec![
            punct(','),
            ident(style_tag.identifier().as_str()),
            punct('='),
            ident(style_tag.identifier().as_str()),
        ]));

        closure_items.push(group(vec![
            ident("let"),
            ident(style_tag.identifier().as_str()),
            punct('='),
            io.clone(),
            punct('.'),
            ident("render_style"),
            parens(vec![string_literal(style_tag.literal().as_str())]),
            punct(';'),
        ]));
    }

    closure_items.push(group(vec![
        io.clone(),
        punct('.'),
        ident(command),
        parens(vec![ident("format"), punct('!'), parens(format_call_args)]),
    ]));

    let result = closure(closure_items);

    Ok(TokenStream::from_iter([result]))
}
