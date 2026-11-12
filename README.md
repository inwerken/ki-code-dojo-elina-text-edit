# ELINA Mail Texts

ABAP report `Z_INW_EINV_MAIL_TEXTS` displays entries from `/INW/EINV_MAIL`
and the associated SO10 standard texts. Import this repository with abapGit
into an ABAP package, activate the report, and run it. Use selection option
`P_VARI` to display and filter `/INW/EINV_MAIL_V` instead.

The selection screen provides filters for every field in `/INW/EINV_MAIL` and
language filters for translations. The ALV shows the mail configuration keys
and the text content. Double-click a text-content column to open its SO10
editor/viewer. Select `P_EDIT` before execution to edit existing texts or
create a missing translation. Select `P_NEW` and enter a name beginning with
`Z_INV` to create a new standard text for the selected languages.

The report does not update either configuration table; their rows are
display-only. Texts are read and saved with the standard SAP text function
modules.
