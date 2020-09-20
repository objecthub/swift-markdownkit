# Sample document
## A few lines of Markdown text

**(make-drawing)**

Returns a new, empty drawing. A _drawing_ consists of a sequence of drawing instructions and
drawing state consisting of the following components:

   - Stroke color (set via `set-color`)
   - Fill color (set via `fill-color`)
   - Shadow (set via `set-shadow` and `remove-shadow`)
   - Transformation (add transformation via `enable-transformation` and remove via `disable-transformation`)

***

**(enum-set-indexer _enum-set_)**

Returns a unary procedure that, given a symbol that is in the universe of _enum-set_,
returns its 0-origin index within the canonical ordering of the symbols in the universe;
given a value not in the universe, the unary procedure returns `#f`.

Returns a unary procedure that, given a symbol that is in the universe of _enum-set_,
returns its 0-origin index within the canonical ordering of the symbols

```
(let* ((e (make-enumeration '(red green blue)))
(i (enum-set-indexer e)))
(list (i 'red) (i 'green) (i 'blue) (i 'yellow)))
⇒ (0 1 2 #f)
```

The `enum-set-indexer` procedure could be defined as follows using the new `memq` procedure.

> And this is a fancy
> blockquote `code block`. This requires special treatment since the HTML to NSAttributedString
> conversion is not able to render blockquote tags.
> 
> ***
>
> This is still in the blockquote.

There is more text coming after the blockquote, including a table:

| Country     | Country code | Dialing code |
| :----------- | :--------------: | :-------------: |
| Albania | AL | +355 |
| Argentina | AR | +54 |
| Austria | AT | +43 |
| Switzerland | CH | +41 |

Description lists also need special treatment when converted to `NSAttributedString`:

One
: This is the description for _One_

Two
: This is the description for _Two_

