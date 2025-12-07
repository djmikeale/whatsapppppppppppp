with
    src as (select * from {{ ref('raw_load') }}),

    remove_stupid_unicode as (
        -- U+202F (NARROW NO-BREAK SPACE) is used. replace with regular space
        select replace(content, ' ', ' ') as content from src
    ),

    split_to_parts as (
        select
            regexp_extract(
                -- note there's a U+200E (Left-to-Right Mark) before the initial
                -- question mark. According to llm:
                -- RE2 doesn’t support \uXXXX escapes, \x{XXXX}, or any other
                -- hex-escape syntax. Hence the literal is used
                content, '\[(.+)\] ([\w \-~]+)((.|\n)*)', ['ts', 'sender', 'message']
            ) as a,
            content
        from remove_stupid_unicode
    ),

    clean_up_message as (
        select
            try_strptime(a.ts, '%-d/%m/%Y, %H.%M.%S') as sent_at,
            a.sender as sender,
            -- some messages are empty - in order to capture them, we include the
            -- ": [rest of message]" / ":" as part of the message, which is then
            -- filtered out:
            case
                when len(a.message) = 1 then '' else substring(a.message, 3)
            end as message,
            content
        from split_to_parts
        -- one message is empty
        where content != ''
    )

select
    sent_at,
    sender,
    message,
    case
        when unicode(message) = -1
        then 'multiple_pictures_begin'
        when unicode(message) = 8206
        then
            case
                when substring(message, 2, 11) = '<attached: '
                then regexp_extract(substr(lower(message), 22), '^([\w]+)')
                else 'unmapped'
            end
        else 'text'
    end as category,
    content
from clean_up_message
