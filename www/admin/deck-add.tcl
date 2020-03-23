# generic header for static .adp pages

set instance_id [ad_conn package_id]
set user_id [ad_conn user_id]
set admin_p [permission::permission_p -party_id $user_id -object_id [ad_conn package_id] -privilege admin]

set title "Add Deck"
set context [list [list ../ "\#flashcards.Flashcards\#" ] [list index "Admin"] $title]
set content_html ""
set user_message_list [list ]
if { $admin_p } {
    set form_html ""
    set form_submitted_p [qf_get_inputs_as_array input_array]
    if { $form_submitted_p } {
	set content_dat $input_array(content_dat)
	set name $input_array(name)
	set description $input_array(description)
    } else {
	append content_html {
	    <p>Content data is expected to be three columns of data,
	    with columns in this order:</p>
	    <ol><li>abbreviations</li>
	    <li>term</li>
	    <li>description</li>
	    </ol>
	    <p>Do not include header names or labels</p>}
    }
    set f_lol [list \
		   [list name name label "Deck name" datatype text_nonempty maxlength 40] \
		   [list name description label "Description" datatype text_nonempty] \
		   [list name content_dat label "Content data" datatype block_text] \
		   [list type submit name submit value "\#acs-kernel.common_Save\#" datatype text_nonempty label "" ]
	      ]


::qfo::form_list_def_to_array \
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
	    
	    
	    lappend user_message_list "Successfully imported ${rows_count} rows."

	    
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

