--
-- flashcards-DROP.sql

DROP index flc_user_stats_user_id_idx;
DROP index flc_user_stats_instance_id_idx;
DROP TABLE flc_user_stats;

DROP index flc_user_stack_instance_id_idx;
DROP index flc_user_stack_user_id_idx;
DROP TABLE flc_user_stack;

DROP index flc_card_stack_card_card_id_idx;
DROP TABLE flc_card_stack_card;
DROP TABLE flc_card_stack;

DROP index flc_content_id_idx;

DROP TABLE flc_content;

DROP SEQUENCE flc_id_seq;
