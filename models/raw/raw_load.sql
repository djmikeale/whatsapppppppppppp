with
    load_txt as (
        select size, parse_path(filename), content, len(content)
        from read_text('/Users/mikaelthorup/_chat.txt')
    ),

    splits as (
        select unnest(string_split_regex(content, '\r\n')) as content from load_txt
    )

select *
from splits
