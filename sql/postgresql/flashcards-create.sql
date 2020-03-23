-- flashcards-create.sql
--
-- flashcards abbreviation: flc_
CREATE SEQUENCE flc_id_seq start 10000;
SELECT nextval ('flc_id_seq');

-- For general raw input data
CREATE TABLE flc_content (
    row_id integer not null,
    content_id integer not null,
    instance_id integer,
    abbreviation varchar(40),
    term varchar(80),
    description text
);

create index flc_content_content_id_idx on flc_content (content_id);
create index flc_content_row_id_idx on flc_content (row_id);

CREATE TABLE flc_card_stack (
     stack_id integer not null primary key,
     instance_id integer,
     name text,
     description text
);

CREATE TABLE flc_card_stack_card (
     card_id integer not null primary key,
     instance_id integer,
     stack_id integer not null,
     content_id integer not null,
     row_id integer not null,
     -- we only need 3 distinct references to specify both sides of a card
     -- from a row of flc_content
     -- a = abbreviation
     -- t = term
     -- d = description
     front_ref varchar(1) not null,
     back_ref varchar(1) not null
);

create index flc_card_stack_card_card_id_idx on flc_card_stack_card (card_id);

CREATE TABLE flc_user_stack (
       instance_id integer,
       user_id integer,
       card_id integer,
       -- shuffling done when user stack created.
       -- skip by multiples of stack size,
       -- so that there is room to insert every card inbetween,
       -- should cards get put back in stack.
       order_id integer,
       -- done_p means remove from active stack
       done_p boolean,
       view_count integer
);

create index flc_user_stack_user_id_idx on flc_user_stack (user_id);
create index flc_user_stack_instance_id_idx on flc_user_stack (instance_id);

CREATE TABLE flc_user_stats (
       instance_id integer,
       user_id integer,
       stack_id integer,
       time_start timestamptz,
       time_end timestamptz,
       cards_completed_count integer,
       cards_remaining_count integer,
       repeats_count integer
);

create index flc_user_stats_instance_id_idx on flc_user_stats (instance_id);
create index flc_user_stats_user_id_idx on flc_user_stats (user_id);

