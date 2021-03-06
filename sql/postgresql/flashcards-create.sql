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
    abbreviation text,
    term text,
    description text
);

create index flc_content_content_id_idx on flc_content (content_id);
create index flc_content_row_id_idx on flc_content (row_id);

CREATE TABLE flc_card_stack (
     stack_id integer not null primary key,
     -- The content_id is a referemce to flc_content
     -- and is the same for an entire deck.
     content_id integer not null,
     instance_id integer,
     card_count integer,
     name text,
     description text
);

CREATE TABLE flc_card_stack_card (
     -- This set of cards defines a deck
     instance_id integer,
     -- card in deck references
     stack_id integer not null,
     card_id integer not null,
     
     -- specific references to build content of card from imported data
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
create index flc_card_stack_card_stack_id_idx on flc_card_stack_card (stack_id);

CREATE TABLE flc_user_stack (
       -- User decks are deck_id based on a generic stack_id
       instance_id integer,
       user_id integer,

       -- references to build deck/stack for user
       deck_id integer,
       card_id integer,
       
       -- shuffling done when user stack created.
       -- skip by multiples of stack size,
       -- so that there is room to insert every card inbetween,
       -- should cards get put back in stack.
       order_id integer,

       -- card state: done_p = 't' means remove from active stack.
       done_p boolean,
       -- number of times the backside of a card has been viewed,
       -- including when user asks that card be kept in deck.
       view_count integer
);

create index flc_user_stack_user_id_idx on flc_user_stack (user_id);
create index flc_user_stack_instance_id_idx on flc_user_stack (instance_id);

CREATE TABLE flc_user_stats (
       instance_id integer,
       user_id integer,
       stack_id integer,
       deck_id integer,
       time_start timestamptz,
       time_end timestamptz,
       cards_completed_count integer,
       cards_remaining_count integer,
       -- repeats_count = total_views - total_cards
       repeats_count integer
);

create index flc_user_stats_instance_id_idx on flc_user_stats (instance_id);
create index flc_user_stats_user_id_idx on flc_user_stats (user_id);

