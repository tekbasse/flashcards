# generic header for static .adp pages

set instance_id [ad_conn package_id]
set user_id [ad_conn user_id]
set admin_p [permission::permission_p -party_id $user_id -object_id [ad_conn package_id] -privilege admin]

set title "Admin"
set context [list [list $title]]
set content_html ""

if { $admin_p } {

    append content_html {<a href="deck-add">Add content for a flashcard deck</a>}
    

} else {
    append content_html "\#flashcards.permission_denied\#"
}
