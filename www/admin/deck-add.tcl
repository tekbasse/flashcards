# generic header for static .adp pages

set instance_id [ad_conn package_id]
set user_id [ad_conn user_id]
set admin_p [permission::permission_p -party_id $user_id -object_id [ad_conn package_id] -privilege admin]

set title "Add Deck"
set context [list $title]
set content_html ""
set user_message_list [list ]
if { $admin_p } {
    set form_html ""
    set form_submitted_p [qf_get_inputs_as_array input_array]
    if { $form_submitted_p } {
        set content_dat $input_array(content_dat)
        set deck_name $input_array(name)
        set deck_description $input_array(description)
    } else {
        append content_html {
            <p>Content data is expected to be three columns of data,
            with columns in this order:</p>
            <ol><li>abbreviations</li>
            <li>term</li>
            <li>description</li>
            </ol>
            <p>Do not include header names or column labels in the data.</p>}
    }
    set f_lol [list \
                   [list name name label "Deck name" datatype text_nonempty maxlength 40] \
                   [list name description label "Description" datatype text_nonempty] \
                   [list name content_dat label "Content data" datatype block_text] \
                   [list type submit name submit value "\#acs-kernel.common_Save\#" datatype text_nonempty label "" ]
              ]


    ::qfo::array_set_form_list \
        -list_of_lists_name f_lol \
        -fields_ordered_list_name qf_fields_ordered_list \
        -array_name f_arr \
        -ignore_parse_issues_p 0
    
    set validated_p [qfo_2g \
                         -form_id 20200322 \
                         -fields_ordered_list $qf_fields_ordered_list \
                         -fields_array f_arr \
                         -inputs_as_array input_array\
                         -form_submitted_p $form_submitted_p \
                         -form_varname form_html ]
    if { $validated_p } {
        # examine content_dat, maybe add to flc_content
        # and name and description to flc_card_stack
        set dat_stats_list [qss_txt_table_stats $content_dat ]
        lassign $dat_stats_list linebreak_char delimiter rows_count columns_count
        if { $columns_count eq 3 } {
            set content_lol [qss_txt_to_tcl_list_of_lists $content_dat \
				 $linebreak_char \
				 $delimiter]
	    set error_p 0
	    set row_count 0
            db_transaction {
		# load content
		set content_id [db_nextval flc_id_seq]
		# generate flashcards from content
		set stack_id [db_nextval flc_id_seq]
		set content_id [db_nextval flc_id_seq]
		set card_id 0
		set row_id 0
		set card_count 0
		foreach row_list $content_lol {
		    lassign $row_list abbreviation term description
		    set abbreviation [qf_abbreviate $abbreviation 37]
		    set term [qf_abbreviate $term 190]
		    # save content
		    incr row_id
		    db_dml flc_content_cr {insert into flc_content 
			(row_id,content_id,instance_id,abbreviation,term,description)
			values (:row_id,:content_id,:instance_id,:abbreviation,:term,:description)}
		    
		    # make cards from row
		    if { $abbreviation ne "" && $term ne "" } {
			incr card_id $rows_count
			incr card_count 2
			db_dml flc_card_stack_card_cr {insert into flc_card_stack_card
			    (card_id,instance_id,stack_id,row_id,front_ref,back_ref)
			    values (:card_id,:instance_id,:stack_id,:row_id,'a','t') }
			incr card_id $rows_count
			db_dml flc_card_stack_card_cr2 {insert into flc_card_stack_card
			    (card_id,instance_id,stack_id,row_id,front_ref,back_ref)
			    values (:card_id,:instance_id,:stack_id,:row_id,'t','a') }
		    }
		    if { $description ne "" && $term ne "" } {
			incr card_id $rows_count
			incr card_count 2
			db_dml flc_card_stack_card_cr {insert into flc_card_stack_card
			    (card_id,instance_id,stack_id,row_id,front_ref,back_ref)
			    values (:card_id,:instance_id,:stack_id,:row_id,'t','d') }
			incr card_id $rows_count
			db_dml flc_card_stack_card_cr2 {insert into flc_card_stack_card
			    (card_id,instance_id,stack_id,row_id,front_ref,back_ref)
			    values (:card_id,:instance_id,:stack_id,:row_id,'d','t') }
		    }
			    
		}

		db_dml flc_card_stack_cr {insert into flc_card_stack
		    (stack_id,content_id,instance_id,name,description,card_count)
		    values (:stack_id,:content_id,:instance_id,:deck_name,:deck_description,:card_count) }
		

	    } on_error { set error_p 1 }
	    if { $error_p } {
		lappend user_message_list "There was an error importing data: '${errmsg}'"
	    } else {
		# cards are added in sets of two, representing either side facing first.
		set flashcard_ct [expr { $card_count / 2 } ]
		lappend user_message_list "Successfully imported ${rows_count} rows into ${flashcard_ct} flashcards."
	    }

            
        } else {
            lappend user_message_list "<pre>Hmm.. I can't parse this data. \n
It appears to be ${columns_count} and not three columns of data. \n
My best guess is that the linebreak character is '${linebreak_char}' \n
and the column delimiter is '${delimiter}'. \n
Please modify the data, then try again.</pre>"
        }
    } 
    set user_message_html ""
    foreach user_message $user_message_list {
        append user_message_html "<li>${user_message}</li>"
    }
    append content_html $form_html
} else {
    append content_html "\#flashcards.permission_denied\#"
}

