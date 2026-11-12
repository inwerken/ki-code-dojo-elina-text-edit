REPORT z_inw_einv_mail_texts.

TABLES /inw/einv_mail.

SELECT-OPTIONS:
  s_mandt FOR /inw/einv_mail-mandt,
  s_vkorg FOR /inw/einv_mail-vkorg,
  s_vtweg FOR /inw/einv_mail-vtweg,
  s_spart FOR /inw/einv_mail-spart,
  s_kschl FOR /inw/einv_mail-kschl,
  s_rec FOR /inw/einv_mail-recipient,
  s_sender FOR /inw/einv_mail-sender,
  s_sub FOR /inw/einv_mail-sub,
  s_sig FOR /inw/einv_mail-sig,
  s_body FOR /inw/einv_mail-body_t_name,
  s_att FOR /inw/einv_mail-att_name,
  s_pdf FOR /inw/einv_mail-pdf_name.

DATA gv_language TYPE thead-tdlanguage.
SELECT-OPTIONS s_langu FOR gv_language.

PARAMETERS:
  p_edit AS CHECKBOX DEFAULT space,
  p_new AS CHECKBOX DEFAULT space,
  p_name TYPE thead-tdname.

TYPES:
  BEGIN OF ty_output,
    INCLUDE TYPE /inw/einv_mail,
    body_text TYPE string,
    sub_text  TYPE string,
    sig_text  TYPE string,
    att_text  TYPE string,
    pdf_text  TYPE string,
  END OF ty_output.

DATA:
  gt_output TYPE STANDARD TABLE OF ty_output,
  go_alv    TYPE REF TO cl_salv_table.

CLASS lcl_events DEFINITION.
  PUBLIC SECTION.
    METHODS on_double_click
      FOR EVENT double_click OF cl_salv_events_table
      IMPORTING row column.
ENDCLASS.

CLASS lcl_events IMPLEMENTATION.
  METHOD on_double_click.
    FIELD-SYMBOLS <ls_output> TYPE ty_output.
    DATA lv_name TYPE thead-tdname.

    READ TABLE gt_output INDEX row ASSIGNING <ls_output>.
    IF sy-subrc <> 0.
      RETURN.
    ENDIF.

    CASE column.
      WHEN 'BODY_TEXT'.
        lv_name = <ls_output>-body_t_name.
      WHEN 'SUB_TEXT'.
        lv_name = <ls_output>-sub.
      WHEN 'SIG_TEXT'.
        lv_name = <ls_output>-sig.
      WHEN 'ATT_TEXT'.
        lv_name = <ls_output>-att_name.
      WHEN 'PDF_TEXT'.
        lv_name = <ls_output>-pdf_name.
      WHEN OTHERS.
        RETURN.
    ENDCASE.

    IF lv_name IS INITIAL.
      MESSAGE 'Für dieses Feld ist kein SO10-Text hinterlegt.' TYPE 'S'.
      RETURN.
    ENDIF.

    PERFORM open_text_for_languages USING lv_name.
  ENDMETHOD.
ENDCLASS.

DATA go_events TYPE REF TO lcl_events.

INITIALIZATION.
  s_langu-sign = 'I'.
  s_langu-option = 'EQ'.
  s_langu-low = sy-langu.
  APPEND s_langu.

AT SELECTION-SCREEN.
  IF p_new = abap_true AND p_name IS INITIAL.
    MESSAGE 'Bitte einen SO10-Textnamen für die Neuanlage eingeben.' TYPE 'E'.
  ENDIF.
  IF p_new = abap_true AND p_name(5) <> 'Z_INV'.
    MESSAGE 'Neue SO10-Texte müssen mit Z_INV beginnen.' TYPE 'E'.
  ENDIF.

START-OF-SELECTION.
  IF p_new = abap_true.
    PERFORM create_text_for_languages USING p_name.
  ELSE.
    PERFORM display_mail_texts.
  ENDIF.

FORM display_mail_texts.
  DATA lt_mail TYPE STANDARD TABLE OF /inw/einv_mail.
  DATA ls_output TYPE ty_output.
  DATA lt_languages TYPE STANDARD TABLE OF t002-spras.

  SELECT *
    FROM /inw/einv_mail
    WHERE mandt IN @s_mandt
      AND vkorg IN @s_vkorg
      AND vtweg IN @s_vtweg
      AND spart IN @s_spart
      AND kschl IN @s_kschl
      AND recipient IN @s_rec
      AND sender IN @s_sender
      AND sub IN @s_sub
      AND sig IN @s_sig
      AND body_t_name IN @s_body
      AND att_name IN @s_att
      AND pdf_name IN @s_pdf
    INTO TABLE @lt_mail.

  IF sy-subrc <> 0.
    MESSAGE 'Keine passenden Einträge gefunden.' TYPE 'S'.
    RETURN.
  ENDIF.

  SELECT spras
    FROM t002
    WHERE spras IN @s_langu
    INTO TABLE @lt_languages.

  LOOP AT lt_mail INTO DATA(ls_mail).
    CLEAR ls_output.
    MOVE-CORRESPONDING ls_mail TO ls_output.
    PERFORM read_text_for_languages USING ls_mail-body_t_name lt_languages CHANGING ls_output-body_text.
    PERFORM read_text_for_languages USING ls_mail-sub lt_languages CHANGING ls_output-sub_text.
    PERFORM read_text_for_languages USING ls_mail-sig lt_languages CHANGING ls_output-sig_text.
    PERFORM read_text_for_languages USING ls_mail-att_name lt_languages CHANGING ls_output-att_text.
    PERFORM read_text_for_languages USING ls_mail-pdf_name lt_languages CHANGING ls_output-pdf_text.
    APPEND ls_output TO gt_output.
  ENDLOOP.

  TRY.
      cl_salv_table=>factory(
        IMPORTING r_salv_table = go_alv
        CHANGING  t_table      = gt_output ).
      go_alv->get_functions( )->set_all( abap_true ).
      go_alv->get_columns( )->set_optimize( abap_true ).
      go_events = NEW lcl_events( ).
      SET HANDLER go_events->on_double_click FOR go_alv->get_event( ).
      go_alv->display( ).
    CATCH cx_salv_msg INTO DATA(lx_salv).
      MESSAGE lx_salv->get_text( ) TYPE 'S' DISPLAY LIKE 'E'.
  ENDTRY.
ENDFORM.

FORM read_text_for_languages
  USING iv_name TYPE thead-tdname
        it_languages TYPE STANDARD TABLE
  CHANGING cv_text TYPE string.
  DATA lv_language TYPE t002-spras.
  DATA lv_text TYPE string.
  CLEAR cv_text.

  IF iv_name IS INITIAL.
    RETURN.
  ENDIF.

  LOOP AT it_languages INTO lv_language.
    PERFORM read_one_text USING iv_name lv_language CHANGING lv_text.
    IF lv_text IS NOT INITIAL.
      IF cv_text IS NOT INITIAL.
        CONCATENATE cv_text cl_abap_char_utilities=>newline INTO cv_text.
      ENDIF.
      CONCATENATE cv_text '[' lv_language '] ' lv_text INTO cv_text.
    ENDIF.
  ENDLOOP.
ENDFORM.

FORM read_one_text
  USING iv_name TYPE thead-tdname
        iv_language TYPE thead-tdlanguage
  CHANGING cv_text TYPE string.
  DATA ls_header TYPE thead.
  DATA lt_lines TYPE STANDARD TABLE OF tline.
  DATA lv_line TYPE string.

  CLEAR cv_text.
  CALL FUNCTION 'READ_TEXT'
    EXPORTING
      id       = 'ST'
      language = iv_language
      name     = iv_name
      object   = 'TEXT'
    IMPORTING
      header   = ls_header
    TABLES
      lines    = lt_lines
    EXCEPTIONS
      not_found = 4
      OTHERS    = 8.
  IF sy-subrc <> 0.
    RETURN.
  ENDIF.

  LOOP AT lt_lines INTO DATA(ls_line).
    lv_line = ls_line-tdline.
    IF cv_text IS NOT INITIAL.
      CONCATENATE cv_text cl_abap_char_utilities=>newline INTO cv_text.
    ENDIF.
    CONCATENATE cv_text lv_line INTO cv_text.
  ENDLOOP.
ENDFORM.

FORM open_text_for_languages USING iv_name TYPE thead-tdname.
  DATA lt_languages TYPE STANDARD TABLE OF t002-spras.
  SELECT spras
    FROM t002
    WHERE spras IN @s_langu
    INTO TABLE @lt_languages.

  LOOP AT lt_languages INTO DATA(lv_language).
    PERFORM edit_one_text USING iv_name lv_language p_edit.
  ENDLOOP.
ENDFORM.

FORM create_text_for_languages USING iv_name TYPE thead-tdname.
  DATA lt_languages TYPE STANDARD TABLE OF t002-spras.
  SELECT spras
    FROM t002
    WHERE spras IN @s_langu
    INTO TABLE @lt_languages.

  LOOP AT lt_languages INTO DATA(lv_language).
    PERFORM edit_one_text USING iv_name lv_language abap_true.
  ENDLOOP.
ENDFORM.

FORM edit_one_text
  USING iv_name TYPE thead-tdname
        iv_language TYPE thead-tdlanguage
        iv_edit TYPE abap_bool.
  DATA ls_header TYPE thead.
  DATA lt_lines TYPE STANDARD TABLE OF tline.
  DATA lv_exists TYPE abap_bool VALUE abap_true.

  ls_header-tdobject = 'TEXT'.
  ls_header-tdid = 'ST'.
  ls_header-tdname = iv_name.
  ls_header-tdlanguage = iv_language.

  CALL FUNCTION 'READ_TEXT'
    EXPORTING
      id       = ls_header-tdid
      language = ls_header-tdlanguage
      name     = ls_header-tdname
      object   = ls_header-tdobject
    IMPORTING
      header   = ls_header
    TABLES
      lines    = lt_lines
    EXCEPTIONS
      not_found = 4
      OTHERS    = 8.
  IF sy-subrc <> 0.
    lv_exists = abap_false.
    CLEAR lt_lines.
  ENDIF.

  IF lv_exists = abap_false AND iv_edit = abap_false.
    MESSAGE |SO10-Text { iv_name } ist in Sprache { iv_language } nicht vorhanden.| TYPE 'S'.
    RETURN.
  ENDIF.

  IF iv_edit = abap_true AND iv_name(5) <> 'Z_INV'.
    MESSAGE 'Bearbeiten ist nur für SO10-Texte mit Präfix Z_INV erlaubt.' TYPE 'S' DISPLAY LIKE 'E'.
    RETURN.
  ENDIF.

  CALL FUNCTION 'EDIT_TEXT'
    EXPORTING
      display      = COND c( WHEN iv_edit = abap_true THEN space ELSE 'X' )
      editor_title = |SO10 { iv_name } ({ iv_language })|
      header       = ls_header
      save         = iv_edit
    TABLES
      lines        = lt_lines
    EXCEPTIONS
      id           = 1
      language     = 2
      name         = 3
      object       = 4
      OTHERS       = 5.
  IF sy-subrc <> 0 OR iv_edit = abap_false.
    RETURN.
  ENDIF.

  CALL FUNCTION 'SAVE_TEXT'
    EXPORTING
      header          = ls_header
      insert          = COND c( WHEN lv_exists = abap_true THEN space ELSE 'X' )
      savemode_direct = abap_true
    TABLES
      lines           = lt_lines
    EXCEPTIONS
      id              = 1
      language        = 2
      name            = 3
      object          = 4
      others          = 5.
  IF sy-subrc = 0.
    COMMIT WORK AND WAIT.
    MESSAGE |SO10-Text { iv_name } ({ iv_language }) wurde gesichert.| TYPE 'S'.
  ELSE.
    MESSAGE |SO10-Text { iv_name } ({ iv_language }) konnte nicht gesichert werden.| TYPE 'S' DISPLAY LIKE 'E'.
  ENDIF.
ENDFORM.
