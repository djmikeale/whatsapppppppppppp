with
    src as (select * from stg_messages),
    only_text as (select * from src where category = 'text'),
    analysis as (
        select
            sent_at,
            sender,
            nullif(regexp_extract(message, '(hah\w*)'), '') as contains_hah,
            len(contains_hah) as len_hah,
            len(message) as len_message,
            right(message, 25) = '<This message was edited>' as is_edited,
            regexp_extract_all(message, '@⁨([^⁩]+)⁩', 0) as mention,
            message
        from only_text
    ),
    analysis_window as (
        select
            *,
            row_number() over (partition by sender order by len_hah desc)
            = 1 as is_longest_hah
        from analysis
    ),
    mention as (select substr(unnest(mention), 2) as mention from analysis),
    mention_agg as (
        select mention[2:-2] as mention, count(*) as n_mentions
        from mention
        group by all
    ),
    aggs as (
        select
            sender,
            count(*) as n_messages_sent,
            sum(len_message) as n_characters_sent,
            any_value(contains_hah) filter (is_longest_hah) as longest_hah
        from analysis_window
        group by 1
    ),
    joins as (
        select aggs.*, n_mentions from aggs left join mention_agg on mention = sender
    )

select *
from joins
