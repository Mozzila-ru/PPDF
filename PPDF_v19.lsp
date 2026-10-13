;;; ============================================================
;;; PPDF v19.0 - Пакетный экспорт в PDF + Объединение
;;; Команда: PPDF
;;; AutoCAD 2014+
;;; ------------------------------------------------------------
;;; База - v18.9 (доработанные режимы выбора: блоки + RECTANG).
;;; Из v18.10 взята двуязычность (RU / EN):
;;;   - словарь строк *PPDF-STR* и функция PPDF-T;
;;;   - выпадашка "LNG" в углу главного окна;
;;;   - язык сохраняется в CFG (ключ "lang");
;;;   - смена языка перерисовывает все диалоги.
;;; Строки НЕ экранируются через \U+XXXX.
;;; Файл сохранять в ANSI (CP1251).
;;; ------------------------------------------------------------
;;; Режимы печати:
;;;   1. Выборочная    - клики по блокам/прямоугольникам
;;;   2. Все блоки     - все экземпляры выбранного блока
;;;   3. Одна рамка    - блок или прямоугольник RECTANG
;;;   4. ЗамкПолилиния - образец блока + замкнутая LWPOLYLINE
;;; ------------------------------------------------------------
;;; Сортировка: По строкам / По столбцам
;;; Имя листов:   префикс_суффикс_NNN.pdf
;;; Имя слияния:  префикс_суффикс_merged.pdf
;;; ------------------------------------------------------------
;;; pdftk.exe положить в папку поддержки AutoCAD
;;; либо в PATH, либо рядом с PPDF.lsp.
;;; ============================================================
(vl-load-com)
;;; ============================================================
;;;  НИЗКОУРОВНЕВЫЕ УТИЛИТЫ
;;; ============================================================
(defun PPDF-pad-left (s n ch / res)
(setq res s)
(while (< (strlen res) n) (setq res (strcat ch res)))
res
)
;;; ============================================================
;;;  ЛОКАЛИЗАЦИЯ
;;; ============================================================
;;; Не экранируем через \U+XXXX - на многих системах AutoCAD
;;; показывает такие последовательности как "????".
(defun PPDF-U (s)
(if (null s) "" s)
)
;;; Текущий язык: "RU" | "EN".
(setq *PPDF-LANG* "RU")
;;; Взять строку по ключу с учётом текущего языка.
;;; Формат элемента: (list "key" "RU" "EN").
(defun PPDF-T (key / pair ru en)
(setq pair (assoc key *PPDF-STR*))
(if pair
(progn
(setq ru (nth 1 pair)
en (nth 2 pair))
(if (null en) (setq en ru))
(if (null ru) (setq ru en))
(PPDF-U (if (= *PPDF-LANG* "EN") en ru)))
(PPDF-U (strcat "?" key "?")))
)
;;; ============================================================
;;;  СЛОВАРЬ СТРОК
;;;  Формат: (list "key" "RU-текст" "EN-текст")
;;; ============================================================
(setq *PPDF-STR*
(list
;; --- Главное окно ---
(list "title"        "PPDF v19.0 - Пакетный экспорт + Объединение"
"PPDF v19.0 - Batch export + Merge")
(list "mode_box"     "Режим печати" "Plot mode")
(list "mode_sel"     "Выборочная"    "Pick")
(list "mode_all"     "Все блоки"     "All blocks")
(list "mode_one"     "Одна рамка"    "Single frame")
(list "mode_poly"    "ЗамкПолилиния" "Closed polyline")
(list "prefix"       "Префикс:"  "Prefix:")
(list "suffix"       "Суффикс:"  "Suffix:")
(list "outpath"      "Папка:"    "Folder:")
(list "browse"       "Обзор..."  "Browse...")
(list "style_box"    "Стиль печати"  "Plot style")
(list "paper_box"    "Формат бумаги" "Paper size")
(list "plotter_box"  "Плоттер"       "Plotter")
(list "orient_box"   "Ориентация"    "Orientation")
(list "orient_port"  "Портретная"    "Portrait")
(list "orient_land"  "Альбомная"     "Landscape")
(list "sort_box"     "Порядок нумерации" "Numbering order")
(list "sort_rows"    "По строкам"   "By rows")
(list "sort_cols"    "По столбцам"  "By columns")
(list "scale"        "Масштаб (100=1:100, 0=Вписать):"
"Scale (100=1:100, 0=Fit):")
(list "merge_after"  "После печати предложить объединение PDF"
"After plot offer PDF merge")
(list "btn_help"     "?" "?")
(list "btn_save"     "Сохранить"     "Save")
(list "btn_open"     "Открыть папку" "Open folder")
(list "btn_print"    "Отбор и печать" "Select and plot")
(list "btn_cancel"   "Отмена"        "Cancel")
;; --- Справка ---
(list "help_title"   "PPDF v19.0 - Справка" "PPDF v19.0 - Help")
(list "h_purpose_b"  "НАЗНАЧЕНИЕ" "PURPOSE")
(list "h_purpose_1"  "  Пакетная печать блоков-рамок в отдельные PDF"
"  Batch plot of frame blocks to separate PDFs")
(list "h_purpose_2"  "  с последующим объединением в один файл."
"  with subsequent merge into a single file.")
(list "h_modes_b"    "1. РЕЖИМЫ ВЫБОРА РАМОК" "1. FRAME SELECTION MODES")
(list "h_modes_1"    "  Выборочная    - клики по блокам/прямоуг. (C - отмена)"
"  Pick        - click blocks/rects (C - undo last)")
(list "h_modes_2"    "  Все блоки     - все экземпляры блока, указанного мышью"
"  All blocks  - all instances of the picked block")
(list "h_modes_3"    "  Одна рамка    - блок или прямоугольник (RECTANG)"
"  Single frame- block or rectangle (RECTANG)")
(list "h_modes_4"    "  ЗамкПолилиния - образец блока + замкнутая LWPOLYLINE"
"  Closed poly - sample block + closed LWPOLYLINE")
(list "h_modes_5"    "                  (берутся блоки внутри контура)"
"                (blocks inside the contour)")
(list "h_names_b"    "2. ИМЕНА И СОРТИРОВКА" "2. NAMES AND SORTING")
(list "h_names_1"    "  Листы:   префикс_суффикс_NNN.pdf"
"  Sheets: prefix_suffix_NNN.pdf")
(list "h_names_2"    "  Слияние: префикс_суффикс_merged.pdf"
"  Merge:  prefix_suffix_merged.pdf")
(list "h_names_3"    "  Нумерация листов продолжает последнюю."
"  Sheet numbering continues from the last one.")
(list "h_names_4"    "  Порядок: По строкам / По столбцам."
"  Order: By rows / By columns.")
(list "h_scale_b"    "3. МАСШТАБ" "3. SCALE")
(list "h_scale_1"    "  Пусто или 0  - Вписать (Fit)."
"  Empty or 0  - Fit.")
(list "h_scale_2"    "  100          - 1:100"
"  100         - 1:100")
(list "h_scale_3"    "  50           - 1:50"
"  50          - 1:50")
(list "h_paper_b"    "4. ФОРМАТЫ БУМАГИ" "4. PAPER SIZES")
(list "h_paper_1"    "  В списке - локализованные имена AutoCAD."
"  List shows localized AutoCAD names.")
(list "h_paper_2"    "  В CFG и API - канонические."
"  CFG and API use canonical names.")
(list "h_merge_b"    "5. ОБЪЕДИНЕНИЕ PDF (pdftk.exe)"
"5. PDF MERGE (pdftk.exe)")
(list "h_merge_1"    "  Имя = префикс_суффикс_merged.pdf"
"  Name = prefix_suffix_merged.pdf")
(list "h_merge_2"    "  (всегда из текущих настроек)."
"  (always from current settings).")
(list "h_merge_3"    "  Режимы: Последняя сессия / Текущая папка / Глобально."
"  Modes: Last session / Current folder / Global.")
(list "h_merge_4"    "  Исходники: Архивировать или Удалить."
"  Sources: Archive or Delete.")
(list "h_merge_5"    "  pdftk.exe - в Support, PATH или рядом с LSP."
"  pdftk.exe - in Support, PATH or near the LSP.")
(list "h_pref_b"     "6. ПРЕДПОЛЁТНАЯ ПРОВЕРКА" "6. PREFLIGHT CHECK")
(list "h_pref_1"     "  Если в папке уже есть PDF - выбор:"
"  If the folder already has PDFs - choose:")
(list "h_pref_2"     "  Продолжить / Очистить / Архивировать / Отмена."
"  Continue / Clean / Archive / Cancel.")
(list "h_arch_b"     "7. АРХИВ ПРИ СЛИЯНИИ" "7. MERGE ARCHIVE")
(list "h_arch_1"     "  Папка: ГодМесяцДень_ЧасыМинуты_merged"
"  Folder: YYYYMMDD_HHMM_merged")
(list "h_arch_2"     "  внутри целевой. Если занята - _01, _02, ..."
"  inside target. If busy - _01, _02, ...")
(list "h_silent_b"   "8. ТИХАЯ ПЕЧАТЬ" "8. SILENT PLOT")
(list "h_silent_1"   "  Настраивается в плоттере DWG To PDF.pc3."
"  Configured in the DWG To PDF.pc3 plotter.")
(list "h_silent_2"   "  Пошаговая инструкция - по кнопке ниже."
"  Step-by-step guide - button below.")
(list "h_mem_b"      "9. ПАМЯТЬ НАСТРОЕК" "9. SETTINGS MEMORY")
(list "h_mem_1"      "  Все настройки и режим слияния сохраняются."
"  All settings and merge mode are saved.")
(list "h_mem_2"      "  Имя merged-файла НЕ запоминается -"
"  The merged file name is NOT remembered -")
(list "h_mem_3"      "  всегда из текущих префикса и суффикса."
"  always from current prefix and suffix.")
(list "h_btn_silent" "Тихая печать" "Silent plot")
(list "h_btn_close"  "Закрыть"      "Close")
;; --- Тихая печать ---
(list "hint_title"   "PPDF - Тихая печать (без открытия PDF)"
"PPDF - Silent plot (no PDF opening)")
(list "hn_why_b"     "ПОЧЕМУ ОТКРЫВАЕТСЯ PDF" "WHY PDF OPENS")
(list "hn_why_1"     "  Драйвер DWG To PDF по умолчанию показывает"
"  DWG To PDF driver by default shows")
(list "hn_why_2"     "  результат печати после каждой публикации."
"  the plot result after each publication.")
(list "hn_why_3"     "  Опция хранится внутри PC3-файла плоттера."
"  The option is stored inside the PC3 file.")
(list "hn_steps_b"   "ШАГИ НАСТРОЙКИ" "CONFIGURATION STEPS")
(list "hn_steps_1"   "  1. Ctrl+P - открыть окно 'Печать'."
"  1. Ctrl+P - open the Plot dialog.")
(list "hn_steps_2"   "  2. В списке плоттеров выбрать DWG To PDF.pc3."
"  2. In the plotter list select DWG To PDF.pc3.")
(list "hn_steps_3"   "  3. Нажать 'Свойства' рядом со списком."
"  3. Click Properties next to the list.")
(list "hn_steps_4"   "  4. В дереве выбрать 'Настройка плоттера' -"
"  4. In the tree select Plotter Configuration -")
(list "hn_steps_5"   "     'Дополнительные свойства' -"
"     Custom Properties -")
(list "hn_steps_6"   "     'Параметры PDF' (Custom Properties)."
"     PDF Options (Custom Properties).")
(list "hn_steps_7"   "  5. Снять галочку 'Показывать результаты'"
"  5. Uncheck Show results in viewer")
(list "hn_steps_8"   "     ('Show results in viewer')."
"     (Show results in viewer).")
(list "hn_steps_9"   "  6. OK. На вопрос 'Сохранить изменения' -"
"  6. OK. When asked Save changes -")
(list "hn_steps_10"  "     'Сохранить в следующем файле'"
"     Save changes to the following file")
(list "hn_steps_11"  "     (Save changes to the following file)."
"     (Save changes to the following file).")
(list "hn_steps_12"  "  7. Дописать к имени PC3 любое англ. слово,"
"  7. Append any English word to the PC3 name,")
(list "hn_steps_13"  "     напр. 'DWG To PDF_Silent.pc3'."
"     e.g. DWG To PDF_Silent.pc3.")
(list "hn_steps_14"  "  8. Закрыть окно печати."
"  8. Close the Plot dialog.")
(list "hn_in_b"      "В PPDF" "IN PPDF")
(list "hn_in_1"      "  В списке плоттеров выбрать новый"
"  In the plotter list select the new")
(list "hn_in_2"      "  'DWG To PDF_Silent.pc3' и сохранить настройки."
"  DWG To PDF_Silent.pc3 and save settings.")
(list "hn_in_3"      "  После этого PDF не будет открываться."
"  After that the PDF will not open.")
(list "hn_note_b"    "ПРИМЕЧАНИЕ" "NOTE")
(list "hn_note_1"    "  Изменение 'на лету' через LISP невозможно -"
"  On-the-fly change via LISP is impossible -")
(list "hn_note_2"    "  AutoCAD хранит эту опцию внутри PC3-файла."
"  AutoCAD stores this option inside the PC3 file.")
(list "hn_ok"        "Понятно" "OK")
;; --- Готово ---
(list "done_title"   "PPDF - Готово" "PPDF - Done")
(list "done_pref"    "Экспортировано: " "Exported: ")
(list "done_sheets"  " листов." " sheets.")
(list "done_folder"  "Папка: " "Folder: ")
(list "done_btn_open" "Открыть папку" "Open folder")
(list "done_btn_mrg"  "Объединить"    "Merge")
(list "done_btn_ok"   "OK"            "OK")
;; --- Объединение ---
(list "mg_title"     "PPDF - Объединение PDF" "PPDF - Merge PDF")
(list "mg_mode_b"    "Режим" "Mode")
(list "mg_m_session" "Последняя сессия" "Last session")
(list "mg_m_folder"  "Текущая папка"    "Current folder")
(list "mg_m_global"  "Глобально"        "Global")
(list "mg_name"      "Имя файла:"       "File name:")
(list "mg_src_b"     "Исходные файлы после слияния"
"Source files after merge")
(list "mg_act_arch"  "Архивировать в _merged" "Archive to _merged")
(list "mg_act_del"   "Удалить"                "Delete")
(list "mg_btn_do"    "Объединить" "Merge")
(list "mg_btn_cancel" "Отмена"    "Cancel")
;; --- Предполётная ---
(list "pf_title"     "PPDF - Внимание" "PPDF - Warning")
(list "pf_msg_pre"   "В целевой папке найдено "
"In the target folder found ")
(list "pf_msg_mid"   " PDF-файлов.
Они могут попасть в объединённый документ."
" PDF files.
They may get into the merged document.")
(list "pf_cont"      "Продолжить"   "Continue")
(list "pf_clean"     "Очистить"     "Clean")
(list "pf_arch"      "Архивировать" "Archive")
(list "pf_cancel"    "Отмена"       "Cancel")
;; --- Финал слияния ---
(list "md_title"     "PPDF - Объединение завершено"
"PPDF - Merge complete")
(list "md_msg"       "PDF успешно объединён."
"PDF merged successfully.")
(list "md_file"      "Файл: "          "File: ")
(list "md_open_dir"  "Открыть папку"   "Open folder")
(list "md_open_file" "Открыть файл"    "Open file")
(list "md_ok"        "OK"              "OK")
;; --- Сообщения ---
(list "msg_cfg_saved"  "Настройки сохранены."
"Settings saved.")
(list "msg_cfg_failed" "Не удалось сохранить настройки."
"Failed to save settings.")
(list "msg_need_2"     "Для объединения нужно минимум два файла."
"Merge requires at least two files.")
(list "msg_no_frames"  "Рамки не выбраны." "No frames selected.")
(list "msg_folder_no"  "Папка не задана."  "Folder not set.")
(list "msg_exported"   "Экспортировано: "  "Exported: ")
(list "msg_sheets"     " листов."          " sheets.")
(list "msg_err_autocad" "Не удалось подключиться к AutoCAD."
"Failed to connect to AutoCAD.")
(list "msg_err_doc"    "Не удалось получить документ."
"Failed to get document.")
(list "msg_err_layout" "Не удалось получить Layout."
"Failed to get Layout.")
(list "msg_err_plot"   "Не удалось получить объект Plot."
"Failed to get Plot object.")
(list "msg_err_plotters" "AutoCAD не вернул список плоттеров."
"AutoCAD returned no plotters.")
(list "msg_err_media"  "Не удалось получить список форматов бумаги."
"Failed to get paper sizes.")
(list "msg_err_dcl"    "Не удалось создать DCL."
"Failed to create DCL.")
(list "msg_err_dcl_load" "Не удалось загрузить DCL."
"Failed to load DCL.")
(list "msg_err_dlg"    "Не удалось открыть окно PPDF."
"Failed to open PPDF dialog.")
(list "msg_err_block"  "Это не блок." "Not a block.")
(list "msg_err_poly"   "Граница должна быть ЗАМКНУТОЙ LWPOLYLINE."
"The boundary must be a CLOSED LWPOLYLINE.")
(list "msg_err_inside" "Внутри полилинии ничего не найдено."
"Nothing found inside the polyline.")
(list "msg_err_rect"   "Не блок и не прямоугольная LWPOLYLINE (RECTANG)."
"Not a block and not a rectangular LWPOLYLINE (RECTANG).")
(list "msg_canceled"   "PPDF: отменено." "PPDF: canceled.")
(list "msg_canceled_u" "PPDF: отменено пользователем."
"PPDF: canceled by user.")
(list "msg_no_merge"   "PPDF: объединение не выполнено."
"PPDF: merge not performed.")
(list "msg_merge_cancel" "PPDF: объединение отменено."
"PPDF: merge canceled.")
(list "msg_preflight_no" "PPDF: отменено пользователем."
"PPDF: canceled by user.")
(list "msg_blocks_not_found" "Блоки не найдены."
"Blocks not found.")
(list "msg_sample_no"  "Образец не указан."
"Sample not picked.")
(list "msg_poly_no"    "Полилиния не указана."
"Polyline not picked.")
(list "msg_plot_set_err" "Не удалось установить плоттер:
"
"Could not set plotter:
")
(list "msg_paper_set_err" "Не удалось установить формат: "
"Could not set paper: ")
;; --- Приглашения в командной строке ---
(list "pr_sel_header"  "
=== Выборочная печать (блок или прямоугольник RECTANG) ==="
"
=== Selective plot (block or RECTANG rectangle) ===")
(list "pr_sel_hint"    "
Клик по рамке-блоку или прямоугольнику - отметить/снять. C - отменить последний. Enter - продолжить."
"
Click a frame block or rectangle to toggle. C - undo last. Enter - continue.")
(list "pr_sel_prompt"  "] Укажите рамку-блок или прямоугольник [C - отмена]: "
"] Pick frame block or rectangle [C - undo]: ")
(list "pr_sel_picked"  "[Отмечено: " "[Picked: ")
(list "pr_sel_undone"  "
[-] Отменён последний. Осталось: "
"
[-] Last undone. Left: ")
(list "pr_sel_nothing" "
[!] Нечего отменять."
"
[!] Nothing to undo.")
(list "pr_sel_bad"     "
[!] Не блок и не прямоугольная LWPOLYLINE (RECTANG)."
"
[!] Not a block and not a rectangular LWPOLYLINE (RECTANG).")
(list "pr_sel_removed" "
[-] Снята. Осталось: "
"
[-] Removed. Left: ")
(list "pr_sel_added"   "
[+] Отмечена №" "
[+] Added #")
(list "pr_one_header"  "
=== Одна рамка ===" "
=== Single frame ===")
(list "pr_one_prompt"  "
Укажите рамку-блок или прямоугольник (RECTANG): "
"
Pick frame block or rectangle (RECTANG): ")
(list "pr_all_header"  "
=== Все блоки выбранного типа ==="
"
=== All blocks of the picked type ===")
(list "pr_all_prompt"  "
Укажите любую рамку для определения типа блока: "
"
Pick any frame to define the block type: ")
(list "pr_poly_header" "
=== ЗамкПолилиния ===" "
=== Closed polyline ===")
(list "pr_poly_sample" "
Укажите образец рамки-блока: "
"
Pick sample frame block: ")
(list "pr_poly_prompt" "
Укажите замкнутую полилинию-контейнер: "
"
Pick closed polyline container: ")
(list "pr_start_num"   "
Начало нумерации: " "
Start numbering: ")
(list "pr_frames"      "
Рамок: "  "
Frames: ")
(list "pr_plotter"     "
Плоттер: " "
Plotter: ")
(list "pr_paper"       "
Формат: "  "
Paper: ")
(list "pr_plotting"    "
Печать..." "
Plotting...")
(list "pr_win_fail"    "
[!] Не удалось установить окно для рамки "
"
[!] Could not set window for frame ")
(list "pr_plot_fail"   "
[!] Ошибка печати: "
"
[!] Plot error: ")
(list "msg_paper_fallback" "' недоступен, использую '"
"' unavailable, using '")
(list "pr_merge_running" "
[PPDF] Объединение "
"
[PPDF] Merging ")
(list "pr_merge_files"   " файлов..." " files...")
(list "pr_merge_archived" "
[PPDF] Архивировано в "
"
[PPDF] Archived to ")
(list "pr_merge_deleted"  "
[PPDF] Удалено " "
[PPDF] Deleted ")
(list "pr_move_fail"      "
[!] Не удалось переместить: "
"
[!] Move failed: ")
(list "pr_delete_fail"    "
[!] Не удалось удалить: "
"
[!] Delete failed: ")
(list "pr_clean_done"     "
[PPDF] Очищено " "
[PPDF] Cleaned ")
(list "pr_clean_files"    " файлов." " files.")
(list "alert_pdftk_missing"
"pdftk.exe не найден!
Положите pdftk.exe в папку поддержки AutoCAD
(C:\\Program Files\\Autodesk\\AutoCAD 20XX\\Support\\)
или в любую папку из Support File Search Path.
Печать будет работать, объединение — нет."
"pdftk.exe not found!
Place pdftk.exe in the AutoCAD support folder
(C:\\Program Files\\Autodesk\\AutoCAD 20XX\\Support\\)
or in any folder from Support File Search Path.
Plot will work, merge will not.")
(list "alert_no_files_merge" "Нет файлов для объединения."
"No files to merge.")
(list "alert_pdftk_failed_1"
"pdftk не создал файл результата.
Код возврата: "
"pdftk did not create the output file.
Return code: ")
(list "alert_pdftk_failed_2"
"
stderr:
"
"
stderr:
")
(list "alert_pdftk_failed_3"
"
Проверьте:
- пути к файлам и папке не содержат лишних символов
- исходные PDF не повреждены и не зашифрованы
- в папке достаточно прав на запись"
"
Check:
- paths have no weird characters
- source PDFs are not corrupted/encrypted
- folder is writable")
(list "alert_empty_stderr" "(пусто)" "(empty)")
(list "alert_folder_missing" "Папка не существует:
"
"Folder does not exist:
")
(list "alert_file_missing"   "Файл не найден:
"
"File not found:
")
(list "alert_path_not_set"   "Путь к файлу не задан."
"File path not set.")
(list "alert_dcl_hint"       "Не удалось открыть окно инструкции."
"Could not open hint dialog.")
(list "alert_paper_fail_pre" "Плоттер не вернул форматы бумаги:
"
"Plotter returned no paper sizes:
")
)
)
;;; ============================================================
;;;  ПУТИ
;;; ============================================================
(defun PPDF-cfgdir ( / d)
(setq d (strcat (getenv "APPDATA") "\\PPDF"))
(if (not (vl-file-directory-p d)) (vl-mkdir d))
d
)
(defun PPDF-cfgpath            () (strcat (PPDF-cfgdir) "\\ppdf_settings.cfg"))
(defun PPDF-dclpath            () (strcat (PPDF-cfgdir) "\\ppdf_dialog.dcl"))
(defun PPDF-helpdclpath        () (strcat (PPDF-cfgdir) "\\ppdf_help.dcl"))
(defun PPDF-hintdclpath        () (strcat (PPDF-cfgdir) "\\ppdf_hint.dcl"))
(defun PPDF-donedclpath        () (strcat (PPDF-cfgdir) "\\ppdf_done.dcl"))
(defun PPDF-mergdclpath        () (strcat (PPDF-cfgdir) "\\ppdf_merge.dcl"))
(defun PPDF-preftdclpath       () (strcat (PPDF-cfgdir) "\\ppdf_preflight.dcl"))
(defun PPDF-mergeddone-dclpath () (strcat (PPDF-cfgdir) "\\ppdf_merged_done.dcl"))
;;; ============================================================
;;;  ДЕФОЛТЫ
;;; ============================================================
(defun PPDF-defaults ()
(list
(cons "prefix"      "frame")
(cons "suffix"      "")
(cons "outpath"     (strcat (getenv "USERPROFILE") "\\Desktop"))
(cons "styleName"   "monochrome.ctb")
(cons "paperName"   "ISO_expand_A4_(297.00_x_210.00_MM)")
(cons "plotter"     "DWG To PDF.pc3")
(cons "orient"      "Landscape")
(cons "scaleStr"    "")
(cons "plotMode"    "S")
(cons "sortMode"    "R")
(cons "mergeAfter"  "1")
(cons "mergeMode"   "SESSION")
(cons "mergeAction" "ARCHIVE")
(cons "lang"        "RU")
)
)
;;; ============================================================
;;;  CFG
;;; ============================================================
(defun PPDF-load-cfg ( / f line kv key val cfg)
(setq cfg (PPDF-defaults))
(setq f (open (PPDF-cfgpath) "r"))
(if f
(progn
(while (setq line (read-line f))
(setq kv (vl-string-search "=" line))
(if kv
(progn
(setq key (substr line 1 kv))
(setq val (substr line (+ kv 2)))
(if (assoc key cfg)
(setq cfg (subst (cons key val) (assoc key cfg) cfg))
(setq cfg (append cfg (list (cons key val))))))))
(close f)))
cfg
)
(defun PPDF-save-cfg (cfg / f ok)
(setq f (open (PPDF-cfgpath) "w"))
(if f    (progn
(foreach kv cfg
(write-line (strcat (car kv) "=" (cdr kv)) f))
(close f)
(setq ok T))
(setq ok nil))
ok
)
(defun PPDF-cfg-set (cfg key val / pair)
(setq pair (assoc key cfg))
(if pair
(subst (cons key val) pair cfg)
(append cfg (list (cons key val))))
)
;;; ============================================================
;;;  ActiveX - безопасные обёртки
;;; ============================================================
(defun PPDF-safe-variant-list (value / v r)
(cond
((null value) nil)
((listp value) value)
(T
(setq r (vl-catch-all-apply
'(lambda () (vlax-variant-value value)) '()))
(if (vl-catch-all-error-p r)
nil
(progn
(setq v r)
(if (listp v)
v
(progn
(setq r (vl-catch-all-apply
'vlax-safearray->list (list v)))
(if (vl-catch-all-error-p r) nil r)))))))
)
(defun PPDF-safe-method-list (obj method / raw)
(setq raw (vl-catch-all-apply
'(lambda () (vlax-invoke-method obj method)) '()))
(if (vl-catch-all-error-p raw) nil (PPDF-safe-variant-list raw))
)
(defun PPDF-safe-get-property (obj prop / r)
(setq r (vl-catch-all-apply
'(lambda () (vlax-get-property obj prop)) '()))
(if (vl-catch-all-error-p r) nil r)
)
(defun PPDF-safe-put-property (obj prop value / r)
(setq r (vl-catch-all-apply
'(lambda () (vlax-put-property obj prop value)) '()))
(not (vl-catch-all-error-p r))
)
(defun PPDF-safe-invoke (obj method args / r)
(setq r (vl-catch-all-apply
'(lambda ()
(apply 'vlax-invoke-method
(append (list obj method) args)))
'()))
(if (vl-catch-all-error-p r) nil T)
)
(defun PPDF-safe-invoke-bool (obj method args / r)
(setq r (vl-catch-all-apply
'(lambda ()
(apply 'vlax-invoke-method
(append (list obj method) args)))
'()))
(cond
((vl-catch-all-error-p r) nil)
((null r) nil)
((eq r :vlax-false) nil)
((eq r :vlax-true)  T)
((eq r T) T)
((and (numberp r) (= r 0)) nil)
(T T))
)
(defun PPDF-refresh-layout (layout / r)
(setq r (vl-catch-all-apply
'(lambda () (vla-RefreshPlotDeviceInfo layout)) '()))
(not (vl-catch-all-error-p r))
)
;;; ============================================================
;;;  Списки плоттеров / стилей
;;; ============================================================
(defun PPDF-get-style-list (layout / lst)
(setq lst (PPDF-safe-method-list layout 'GetPlotStyleTableNames))
(if lst (cons "None (Color)" lst) (list "None (Color)"))
)
(defun PPDF-get-plotter-list (layout / lst cur)
(setq lst (PPDF-safe-method-list layout 'GetPlotDeviceNames))
(setq cur (PPDF-safe-get-property layout 'ConfigName))
(if (and cur (/= cur "") (not (member cur lst)))
(setq lst (cons cur lst)))
lst
)
(defun PPDF-only-pdf-plotters (lst / result)
(setq result nil)
(foreach plt lst
(if (and plt
(/= plt "")
(/= (strcase plt) "NONE")
(/= (strcase plt) "НЕТ")
(or (wcmatch (strcase plt) "*DWG TO PDF*")
(wcmatch (strcase plt) "*AUTOCAD PDF*")))
(setq result (cons plt result))))
(reverse result)
)
;;; ============================================================
;;;  Форматы бумаги: canon + locale
;;; ============================================================
(defun PPDF-get-media-lists (layout / canon locale r)
(setq canon (PPDF-safe-method-list layout 'GetCanonicalMediaNames))
(if (null canon) (setq canon '()))
(setq locale
(mapcar
'(lambda (c)
(setq r (vl-catch-all-apply
'(lambda () (vla-GetLocaleMediaName layout c)) '()))
(if (or (vl-catch-all-error-p r) (null r) (= r ""))
c
r))
canon))
(list canon locale)
)
(defun PPDF-agree-media (desired available / result)
(cond
((or (null available) (null desired)) (car available))
((member desired available) desired)
((setq result (car (vl-remove-if-not
'(lambda (s) (wcmatch (strcase s) "*A4*"))
available)))
result)
((setq result (car (vl-remove-if-not
'(lambda (s) (wcmatch (strcase s) "*ISO*A4*"))
available)))
result)
((setq result (car (vl-remove-if-not
'(lambda (s) (wcmatch (strcase s) "*LETTER*"))
available)))
result)
(T (car available))
)
)
;;; ============================================================
;;;  DCL - главный диалог
;;; ============================================================
(defun PPDF-write-dcl ( / f)
(setq f (open (PPDF-dclpath) "w"))
(if (not f) nil
(progn
(write-line "ppdf_dialog : dialog {" f)
(write-line (strcat "  label = \"" (PPDF-T "title") "\";") f)
(write-line "  : column {" f)
;; Верхняя строка: подпись-заполнитель + выпадашка LNG справа
(write-line "    : row {" f)
(write-line "      : spacer { width = 1; }" f)
(write-line "      : spacer { width = 1; }" f)
(write-line "      : popup_list { key = \"lang\"; width = 8; fixed_width = true; }" f)
(write-line "    }" f)
(write-line (strcat "    : boxed_row { label = \"" (PPDF-T "mode_box") "\";") f)
(write-line (strcat "      : radio_button { label = \"" (PPDF-T "mode_sel")
"\"; key = \"mode_sel\"; }") f)
(write-line (strcat "      : radio_button { label = \"" (PPDF-T "mode_all")
"\"; key = \"mode_all\"; }") f)
(write-line (strcat "      : radio_button { label = \"" (PPDF-T "mode_one")
"\"; key = \"mode_one\"; }") f)
(write-line (strcat "      : radio_button { label = \"" (PPDF-T "mode_poly")
"\"; key = \"mode_poly\"; }") f)
(write-line "    }" f)
(write-line "    : row {" f)
(write-line (strcat "      : edit_box { label = \"" (PPDF-T "prefix")
"\"; key = \"prefix\"; edit_width = 32; fixed_width = true; }") f)
(write-line (strcat "      : edit_box { label = \"" (PPDF-T "suffix")
"\"; key = \"suffix\"; edit_width = 32; fixed_width = true; }") f)
(write-line "    }" f)
(write-line "    : row {" f)
(write-line (strcat "      : edit_box { label = \"" (PPDF-T "outpath")
"\"; key = \"outpath\"; edit_width = 60; }") f)
(write-line (strcat "      : button { label = \"" (PPDF-T "browse")
"\"; key = \"click_folder\"; width = 12; height = 2.0; }") f)
(write-line "    }" f)
(write-line "    : row {" f)
(write-line (strcat "      : boxed_column { label = \"" (PPDF-T "style_box") "\";") f)
(write-line "        : list_box { key = \"style\"; height = 9; width = 38; fixed_width = true; } }" f)
(write-line (strcat "      : boxed_column { label = \"" (PPDF-T "paper_box") "\";") f)
(write-line "        : list_box { key = \"paper\"; height = 9; width = 42; fixed_width = true; } }" f)
(write-line "    }" f)
(write-line "    : row {" f)
(write-line (strcat "      : boxed_column { label = \"" (PPDF-T "plotter_box") "\";") f)
(write-line "        : list_box { key = \"plotter\"; height = 7; width = 42; fixed_width = true; } }" f)
(write-line (strcat "      : boxed_column { label = \"" (PPDF-T "orient_box") "\";") f)
(write-line (strcat "        : radio_button { label = \"" (PPDF-T "orient_port")
"\"; key = \"orient_portrait\"; }") f)
(write-line (strcat "        : radio_button { label = \"" (PPDF-T "orient_land")
"\"; key = \"orient_landscape\"; }") f)
(write-line "      }" f)
(write-line "    }" f)
(write-line "    : row {" f)
(write-line (strcat "      : boxed_row { label = \"" (PPDF-T "sort_box") "\";") f)
(write-line (strcat "        : radio_button { label = \"" (PPDF-T "sort_rows")
"\"; key = \"sort_rows\"; }") f)
(write-line (strcat "        : radio_button { label = \"" (PPDF-T "sort_cols")
"\"; key = \"sort_cols\"; }") f)
(write-line "      }" f)
(write-line (strcat "      : edit_box { label = \"" (PPDF-T "scale")
"\"; key = \"scale\"; edit_width = 12; }") f)
(write-line "    }" f)
(write-line (strcat "    : toggle { label = \"" (PPDF-T "merge_after")
"\"; key = \"merge_after\"; }") f)
(write-line "    spacer;" f)
(write-line "    : row {" f)
(write-line (strcat "      : button { label = \"" (PPDF-T "btn_help")
"\"; key = \"show_help\"; width = 4; height = 2.2; }") f)
(write-line (strcat "      : button { label = \"" (PPDF-T "btn_save")
"\"; key = \"save_cfg\"; width = 18; height = 2.2; }") f)
(write-line (strcat "      : button { label = \"" (PPDF-T "btn_open")
"\"; key = \"open_folder\"; width = 18; height = 2.2; }") f)
(write-line (strcat "      : button { label = \"" (PPDF-T "btn_print")
"\"; key = \"do_print\"; width = 22; height = 2.2; is_default = true; }") f)
(write-line (strcat "      : button { label = \"" (PPDF-T "btn_cancel")
"\"; key = \"cancel\"; width = 14; height = 2.2; is_cancel = true; }") f)
(write-line "    }" f)
(write-line "  }" f)
(write-line "}" f)
(close f) T))
)
;;; ============================================================
;;;  DCL - справка
;;; ============================================================
(defun PPDF-write-help-dcl ( / f)
(setq f (open (PPDF-helpdclpath) "w"))
(if (not f) nil
(progn
(write-line "ppdf_help : dialog {" f)
(write-line (strcat "  label = \"" (PPDF-T "help_title") "\";") f)
(write-line "  : column {" f)
(write-line (strcat "    : boxed_column { label = \"" (PPDF-T "h_purpose_b") "\";") f)
(write-line (strcat "      : text { label = \"" (PPDF-T "h_purpose_1") "\"; }") f)
(write-line (strcat "      : text { label = \"" (PPDF-T "h_purpose_2") "\"; }") f)
(write-line "    }" f)
(write-line (strcat "    : boxed_column { label = \"" (PPDF-T "h_modes_b") "\";") f)
(write-line (strcat "      : text { label = \"" (PPDF-T "h_modes_1") "\"; }") f)
(write-line (strcat "      : text { label = \"" (PPDF-T "h_modes_2") "\"; }") f)
(write-line (strcat "      : text { label = \"" (PPDF-T "h_modes_3") "\"; }") f)
(write-line (strcat "      : text { label = \"" (PPDF-T "h_modes_4") "\"; }") f)
(write-line (strcat "      : text { label = \"" (PPDF-T "h_modes_5") "\"; }") f)
(write-line "    }" f)
(write-line (strcat "    : boxed_column { label = \"" (PPDF-T "h_names_b") "\";") f)
(write-line (strcat "      : text { label = \"" (PPDF-T "h_names_1") "\"; }") f)
(write-line (strcat "      : text { label = \"" (PPDF-T "h_names_2") "\"; }") f)
(write-line (strcat "      : text { label = \"" (PPDF-T "h_names_3") "\"; }") f)
(write-line (strcat "      : text { label = \"" (PPDF-T "h_names_4") "\"; }") f)
(write-line "    }" f)
(write-line (strcat "    : boxed_column { label = \"" (PPDF-T "h_scale_b") "\";") f)
(write-line (strcat "      : text { label = \"" (PPDF-T "h_scale_1") "\"; }") f)
(write-line (strcat "      : text { label = \"" (PPDF-T "h_scale_2") "\"; }") f)
(write-line (strcat "      : text { label = \"" (PPDF-T "h_scale_3") "\"; }") f)
(write-line "    }" f)
(write-line (strcat "    : boxed_column { label = \"" (PPDF-T "h_paper_b") "\";") f)
(write-line (strcat "      : text { label = \"" (PPDF-T "h_paper_1") "\"; }") f)
(write-line (strcat "      : text { label = \"" (PPDF-T "h_paper_2") "\"; }") f)
(write-line "    }" f)
(write-line (strcat "    : boxed_column { label = \"" (PPDF-T "h_merge_b") "\";") f)
(write-line (strcat "      : text { label = \"" (PPDF-T "h_merge_1") "\"; }") f)
(write-line (strcat "      : text { label = \"" (PPDF-T "h_merge_2") "\"; }") f)
(write-line (strcat "      : text { label = \"" (PPDF-T "h_merge_3") "\"; }") f)
(write-line (strcat "      : text { label = \"" (PPDF-T "h_merge_4") "\"; }") f)
(write-line (strcat "      : text { label = \"" (PPDF-T "h_merge_5") "\"; }") f)
(write-line "    }" f)
(write-line (strcat "    : boxed_column { label = \"" (PPDF-T "h_pref_b") "\";") f)
(write-line (strcat "      : text { label = \"" (PPDF-T "h_pref_1") "\"; }") f)
(write-line (strcat "      : text { label = \"" (PPDF-T "h_pref_2") "\"; }") f)
(write-line "    }" f)
(write-line (strcat "    : boxed_column { label = \"" (PPDF-T "h_arch_b") "\";") f)
(write-line (strcat "      : text { label = \"" (PPDF-T "h_arch_1") "\"; }") f)
(write-line (strcat "      : text { label = \"" (PPDF-T "h_arch_2") "\"; }") f)
(write-line "    }" f)
(write-line (strcat "    : boxed_column { label = \"" (PPDF-T "h_silent_b") "\";") f)
(write-line (strcat "      : text { label = \"" (PPDF-T "h_silent_1") "\"; }") f)
(write-line (strcat "      : text { label = \"" (PPDF-T "h_silent_2") "\"; }") f)
(write-line "    }" f)
(write-line (strcat "    : boxed_column { label = \"" (PPDF-T "h_mem_b") "\";") f)
(write-line (strcat "      : text { label = \"" (PPDF-T "h_mem_1") "\"; }") f)
(write-line (strcat "      : text { label = \"" (PPDF-T "h_mem_2") "\"; }") f)
(write-line (strcat "      : text { label = \"" (PPDF-T "h_mem_3") "\"; }") f)
(write-line "    }" f)
(write-line "    spacer;" f)
(write-line "    : row {" f)
(write-line (strcat "      : button { label = \"" (PPDF-T "h_btn_silent")
"\"; key = \"silent\"; width = 20; height = 2.0; }") f)
(write-line (strcat "      : button { label = \"" (PPDF-T "h_btn_close")
"\"; key = \"close_help\"; width = 16; height = 2.0; is_default = true; is_cancel = true; }") f)
(write-line "    }" f)
(write-line "  }" f)
(write-line "}" f)
(close f) T))
)
;;; ============================================================
;;;  DCL - инструкция по тихой печати
;;; ============================================================
(defun PPDF-write-hint-dcl ( / f)
(setq f (open (PPDF-hintdclpath) "w"))
(if (not f) nil
(progn
(write-line "ppdf_hint : dialog {" f)
(write-line (strcat "  label = \"" (PPDF-T "hint_title") "\";") f)
(write-line "  : column {" f)
(write-line (strcat "    : boxed_column { label = \"" (PPDF-T "hn_why_b") "\";") f)
(write-line (strcat "      : text { label = \"" (PPDF-T "hn_why_1") "\"; }") f)
(write-line (strcat "      : text { label = \"" (PPDF-T "hn_why_2") "\"; }") f)
(write-line (strcat "      : text { label = \"" (PPDF-T "hn_why_3") "\"; }") f)
(write-line "    }" f)
(write-line (strcat "    : boxed_column { label = \"" (PPDF-T "hn_steps_b") "\";") f)
(write-line (strcat "      : text { label = \"" (PPDF-T "hn_steps_1") "\"; }") f)
(write-line (strcat "      : text { label = \"" (PPDF-T "hn_steps_2") "\"; }") f)
(write-line (strcat "      : text { label = \"" (PPDF-T "hn_steps_3") "\"; }") f)
(write-line (strcat "      : text { label = \"" (PPDF-T "hn_steps_4") "\"; }") f)
(write-line (strcat "      : text { label = \"" (PPDF-T "hn_steps_5") "\"; }") f)
(write-line (strcat "      : text { label = \"" (PPDF-T "hn_steps_6") "\"; }") f)
(write-line (strcat "      : text { label = \"" (PPDF-T "hn_steps_7") "\"; }") f)
(write-line (strcat "      : text { label = \"" (PPDF-T "hn_steps_8") "\"; }") f)
(write-line (strcat "      : text { label = \"" (PPDF-T "hn_steps_9") "\"; }") f)
(write-line (strcat "      : text { label = \"" (PPDF-T "hn_steps_10") "\"; }") f)
(write-line (strcat "      : text { label = \"" (PPDF-T "hn_steps_11") "\"; }") f)
(write-line (strcat "      : text { label = \"" (PPDF-T "hn_steps_12") "\"; }") f)
(write-line (strcat "      : text { label = \"" (PPDF-T "hn_steps_13") "\"; }") f)
(write-line (strcat "      : text { label = \"" (PPDF-T "hn_steps_14") "\"; }") f)
(write-line "    }" f)
(write-line (strcat "    : boxed_column { label = \"" (PPDF-T "hn_in_b") "\";") f)
(write-line (strcat "      : text { label = \"" (PPDF-T "hn_in_1") "\"; }") f)
(write-line (strcat "      : text { label = \"" (PPDF-T "hn_in_2") "\"; }") f)
(write-line (strcat "      : text { label = \"" (PPDF-T "hn_in_3") "\"; }") f)
(write-line "    }" f)
(write-line (strcat "    : boxed_column { label = \"" (PPDF-T "hn_note_b") "\";") f)
(write-line (strcat "      : text { label = \"" (PPDF-T "hn_note_1") "\"; }") f)
(write-line (strcat "      : text { label = \"" (PPDF-T "hn_note_2") "\"; }") f)
(write-line "    }" f)
(write-line "    spacer;" f)
(write-line (strcat "    : button { label = \"" (PPDF-T "hn_ok")
"\"; key = \"close_hint\"; is_default = true; is_cancel = true; }") f)
(write-line "  }" f)
(write-line "}" f)
(close f) T))
)
;;; ============================================================
;;;  DCL - готово
;;; ============================================================
(defun PPDF-write-done-dcl ( / f)
(setq f (open (PPDF-donedclpath) "w"))
(if (not f) nil
(progn
(write-line "ppdf_done : dialog {" f)
(write-line (strcat "  label = \"" (PPDF-T "done_title") "\";") f)
(write-line "  : column {" f)
(write-line "    : text { key = \"done_msg\"; }" f)
(write-line "    : text { key = \"done_path\"; }" f)
(write-line "    spacer;" f)
(write-line "    : row {" f)
(write-line (strcat "      : button { label = \"" (PPDF-T "done_btn_open")
"\"; key = \"open\"; width = 18; }") f)
(write-line (strcat "      : button { label = \"" (PPDF-T "done_btn_mrg")
"\"; key = \"merge\"; width = 18; }") f)
(write-line (strcat "      : button { label = \"" (PPDF-T "done_btn_ok")
"\"; key = \"ok\"; width = 12; is_default = true; is_cancel = true; }") f)
(write-line "    }" f)
(write-line "  }" f)
(write-line "}" f)
(close f) T))
)
;;; ============================================================
;;;  DCL - окно объединения
;;; ============================================================
(defun PPDF-write-merge-dcl ( / f)
(setq f (open (PPDF-mergdclpath) "w"))
(if (not f) nil
(progn
(write-line "ppdf_merge : dialog {" f)
(write-line (strcat "  label = \"" (PPDF-T "mg_title") "\";") f)
(write-line "  : column {" f)
(write-line (strcat "    : boxed_row { label = \"" (PPDF-T "mg_mode_b") "\";") f)
(write-line (strcat "      : radio_button { label = \"" (PPDF-T "mg_m_session")
"\"; key = \"mode_session\"; }") f)
(write-line (strcat "      : radio_button { label = \"" (PPDF-T "mg_m_folder")
"\"; key = \"mode_folder\"; }") f)
(write-line (strcat "      : radio_button { label = \"" (PPDF-T "mg_m_global")
"\"; key = \"mode_global\"; }") f)
(write-line "    }" f)
(write-line (strcat "    : edit_box { label = \"" (PPDF-T "mg_name")
"\"; key = \"merged_name\"; edit_width = 60; }") f)
(write-line (strcat "    : boxed_row { label = \"" (PPDF-T "mg_src_b") "\";") f)
(write-line (strcat "      : radio_button { label = \"" (PPDF-T "mg_act_arch")
"\"; key = \"act_archive\"; }") f)
(write-line (strcat "      : radio_button { label = \"" (PPDF-T "mg_act_del")
"\"; key = \"act_delete\"; }") f)
(write-line "    }" f)
(write-line "    spacer;" f)
(write-line "    : row {" f)
(write-line (strcat "      : button { label = \"" (PPDF-T "mg_btn_do")
"\"; key = \"do_merge\"; width = 22; is_default = true; }") f)
(write-line (strcat "      : button { label = \"" (PPDF-T "mg_btn_cancel")
"\"; key = \"cancel\"; width = 14; is_cancel = true; }") f)
(write-line "    }" f)
(write-line "  }" f)
(write-line "}" f)
(close f) T))
)
;;; ============================================================
;;;  DCL - предполётная проверка
;;; ============================================================
(defun PPDF-write-preft-dcl ( / f)
(setq f (open (PPDF-preftdclpath) "w"))
(if (not f) nil
(progn
(write-line "ppdf_preflight : dialog {" f)
(write-line (strcat "  label = \"" (PPDF-T "pf_title") "\";") f)
(write-line "  : column {" f)
(write-line "    : text { key = \"msg\"; width = 60; }" f)
(write-line "    spacer;" f)
(write-line "    : row {" f)
(write-line (strcat "      : button { label = \"" (PPDF-T "pf_cont")
"\"; key = \"cont\"; width = 18; is_default = true; }") f)
(write-line (strcat "      : button { label = \"" (PPDF-T "pf_clean")
"\"; key = \"clean\"; width = 18; }") f)
(write-line (strcat "      : button { label = \"" (PPDF-T "pf_arch")
"\"; key = \"arch\"; width = 18; }") f)
(write-line (strcat "      : button { label = \"" (PPDF-T "pf_cancel")
"\"; key = \"cancel\"; width = 14; is_cancel = true; }") f)
(write-line "    }" f)
(write-line "  }" f)
(write-line "}" f)
(close f) T))
)
;;; ============================================================
;;;  DCL - финал после слияния
;;; ============================================================
(defun PPDF-write-merged-done-dcl ( / f)
(setq f (open (PPDF-mergeddone-dclpath) "w"))
(if (not f) nil
(progn
(write-line "ppdf_merged_done : dialog {" f)
(write-line (strcat "  label = \"" (PPDF-T "md_title") "\";") f)
(write-line "  : column {" f)
(write-line "    : text { key = \"msg\"; }" f)
(write-line "    : text { key = \"path\"; width = 70; }" f)
(write-line "    spacer;" f)
(write-line "    : row {" f)
(write-line (strcat "      : button { label = \"" (PPDF-T "md_open_dir")
"\"; key = \"open_folder\"; width = 18; }") f)
(write-line (strcat "      : button { label = \"" (PPDF-T "md_open_file")
"\"; key = \"open_file\"; width = 18; }") f)
(write-line (strcat "      : button { label = \"" (PPDF-T "md_ok")
"\"; key = \"ok\"; width = 12; is_default = true; is_cancel = true; }") f)
(write-line "    }" f)
(write-line "  }" f)
(write-line "}" f)
(close f) T))
)
;;; ============================================================
;;;  Показ диалогов
;;; ============================================================
(defun PPDF-show-help ( / dcl_id res)
(setq res 0)
(if (PPDF-write-help-dcl)
(progn
(setq dcl_id (load_dialog (PPDF-helpdclpath)))
(if (>= dcl_id 0)
(progn
(if (new_dialog "ppdf_help" dcl_id)
(progn
(action_tile "silent"     "(done_dialog 1)")
(action_tile "close_help" "(done_dialog 0)")
(setq res (start_dialog)))
(setq res 0))
(unload_dialog dcl_id))
(setq res 0))))
(if (= res 1) (PPDF-show-hint))
(princ)
)
(defun PPDF-show-hint ( / dcl_id)
(if (PPDF-write-hint-dcl)
(progn
(setq dcl_id (load_dialog (PPDF-hintdclpath)))
(if (>= dcl_id 0)
(progn
(if (new_dialog "ppdf_hint" dcl_id)
(progn
(action_tile "close_hint" "(done_dialog 0)")
(start_dialog))
(alert (PPDF-T "alert_dcl_hint")))
(unload_dialog dcl_id)))))
(princ)
)
(defun PPDF-show-done (counter outpath / dcl_id res)
(if (PPDF-write-done-dcl)
(progn
(setq dcl_id (load_dialog (PPDF-donedclpath)))
(if (>= dcl_id 0)
(progn
(if (new_dialog "ppdf_done" dcl_id)
(progn
(set_tile "done_msg"
(strcat (PPDF-T "done_pref") (itoa counter) (PPDF-T "done_sheets")))
(set_tile "done_path"
(strcat (PPDF-T "done_folder") outpath))
(if (< counter 2)
(mode_tile "merge" 1))
(action_tile "open"  "(done_dialog 1)")
(action_tile "merge" "(done_dialog 2)")
(action_tile "ok"    "(done_dialog 0)")
(setq res (start_dialog)))
(setq res 0))
(unload_dialog dcl_id)
(if (null res) 0 res))
0))
0)
)
(defun PPDF-show-merged-done (mergedFile / dcl_id res outpath)
(setq outpath (vl-filename-directory mergedFile))
(if (PPDF-write-merged-done-dcl)
(progn
(setq dcl_id (load_dialog (PPDF-mergeddone-dclpath)))
(if (>= dcl_id 0)
(progn
(if (new_dialog "ppdf_merged_done" dcl_id)
(progn
(set_tile "msg"  (PPDF-T "md_msg"))
(set_tile "path" (strcat (PPDF-T "md_file") mergedFile))
(action_tile "open_folder" "(done_dialog 1)")
(action_tile "open_file"   "(done_dialog 2)")
(action_tile "ok"          "(done_dialog 0)")
(setq res (start_dialog)))
(setq res 0))
(unload_dialog dcl_id)
(cond
((= res 1) (PPDF-open-folder outpath))
((= res 2) (PPDF-open-file mergedFile))))
0))
0)
(princ)
)
;;; Диалог слияния: имя приходит снаружи (собранное из префикса/суффикса).
;;; Пользователь может его переписать, но это НЕ сохраняется в CFG.
(defun PPDF-merge-dialog (defaultName startMode startAction
/ dcl_id res mergedName mode action)
(setq mergedName defaultName
mode   (if (and startMode (/= startMode "")) startMode "SESSION")
action (if (and startAction (/= startAction "")) startAction "ARCHIVE"))
(if (PPDF-write-merge-dcl)
(progn
(setq dcl_id (load_dialog (PPDF-mergdclpath)))
(if (>= dcl_id 0)
(progn
(if (new_dialog "ppdf_merge" dcl_id)
(progn
(set_tile "merged_name" defaultName)
(cond
((= mode "FOLDER") (set_tile "mode_folder" "1"))
((= mode "GLOBAL") (set_tile "mode_global" "1"))
(T                 (set_tile "mode_session" "1")))
(if (= action "DELETE")
(set_tile "act_delete" "1")
(set_tile "act_archive" "1"))
(action_tile "do_merge"
(strcat
"(setq mergedName (get_tile \"merged_name\"))"
"(setq mode (cond"
"  ((= (get_tile \"mode_session\") \"1\") \"SESSION\")"
"  ((= (get_tile \"mode_folder\")  \"1\") \"FOLDER\")"
"  (T \"GLOBAL\")))"
"(setq action (if (= (get_tile \"act_delete\") \"1\")"
"                 \"DELETE\" \"ARCHIVE\"))"
"(done_dialog 1)"))
(action_tile "cancel" "(done_dialog 0)")
(setq res (start_dialog)))
(setq res 0))
(unload_dialog dcl_id)
(if (= res 1) (list mergedName mode action) nil))
nil))
nil)
)
;;; ============================================================
;;;  Утилиты
;;; ============================================================
(defun PPDF-move-file (src dst / )
(if (or (null src) (null dst)) nil
(if (vl-file-rename src dst)
T
(if (vl-file-copy src dst)
(progn (vl-file-delete src) T)
nil)))
)
;;; Метка времени ГодМесяцДень_ЧасыМинуты (20251001_1435)
(defun PPDF-timestamp ( / cd y mo d rest h mi)
(setq cd (getvar "cdate"))
(setq y  (fix (/ cd 10000)))
(setq mo (fix (/ (- cd (* y 10000)) 100)))
(setq d  (fix (- cd (* y 10000) (* mo 100))))
(setq rest (- cd (fix cd)))
(setq h  (fix (* rest 24)))
(setq mi (fix (* (- (* rest 24) h) 60)))
(strcat
(PPDF-pad-left (itoa y)  4 "0")
(PPDF-pad-left (itoa mo) 2 "0")
(PPDF-pad-left (itoa d)  2 "0")
"_"
(PPDF-pad-left (itoa h)  2 "0")
(PPDF-pad-left (itoa mi) 2 "0"))
)
;;; Уникальное имя папки: baseName, baseName_01, baseName_02 ... _99
(defun PPDF-unique-dir (outPath baseName / candidate i found)
(setq candidate (strcat outPath baseName "\\"))
(if (not (vl-file-directory-p candidate))
candidate
(progn
(setq i 1 found nil)
(while (and (<= i 99) (null found))
(setq candidate
(strcat outPath baseName "_"
(PPDF-pad-left (itoa i) 2 "0")
"\\"))
(if (not (vl-file-directory-p candidate))
(setq found T)
(setq i (1+ i))))
(if found
candidate
(strcat outPath baseName "_00\\"))))
)
;;; ------------------------------------------------------------
;;;  Предполётная проверка
;;; ------------------------------------------------------------
(defun PPDF-preflight-check (outpath / files count dcl_id res archiveDir ts src dst)
(setq files (vl-directory-files outpath "*.pdf" 1)
count (length files))
(if (= count 0)
T
(if (not (PPDF-write-preft-dcl))
T
(progn
(setq dcl_id (load_dialog (PPDF-preftdclpath)))
(if (< dcl_id 0)
T
(progn
(if (new_dialog "ppdf_preflight" dcl_id)
(progn
(set_tile "msg"
(strcat (PPDF-T "pf_msg_pre")
(itoa count)
(PPDF-T "pf_msg_mid")))
(action_tile "cont"   "(done_dialog 1)")
(action_tile "clean"  "(done_dialog 2)")
(action_tile "arch"   "(done_dialog 3)")
(action_tile "cancel" "(done_dialog 0)")
(setq res (start_dialog)))
(setq res 1))
(unload_dialog dcl_id)
(cond
((= res 0) nil)
((= res 1) T)
((= res 2)
(foreach f files
(vl-file-delete (strcat outpath f)))
(princ (strcat (PPDF-T "pr_clean_done")
(itoa count)
(PPDF-T "pr_clean_files")))
T)
((= res 3)
(setq ts (PPDF-timestamp))
(setq archiveDir (strcat outpath ts "_archive\\"))
(if (not (vl-file-directory-p archiveDir))
(vl-mkdir archiveDir))
(foreach f files
(setq src (strcat outpath f)
dst (strcat archiveDir f))
(if (not (PPDF-move-file src dst))
(princ (strcat (PPDF-T "pr_move_fail") f))))
(princ (strcat (PPDF-T "pr_merge_archived") archiveDir))
T)
(T T)))))))
)
;;; ------------------------------------------------------------
;;;  BBox / подсветка / имена
;;; ------------------------------------------------------------
(defun PPDF-bbox (ent / obj mn mx r)
(setq obj (vlax-ename->vla-object ent))
(setq r
(vl-catch-all-apply
'(lambda ()
(vla-getboundingbox obj 'mn 'mx)
(list (vlax-safearray-get-element mn 0)
(vlax-safearray-get-element mn 1)
(vlax-safearray-get-element mx 0)
(vlax-safearray-get-element mx 1)))
'()))
(if (vl-catch-all-error-p r) nil r)
)
(defun PPDF-highlight (entList / ss)
(if entList
(progn
(setq ss (ssadd))
(foreach e entList (ssadd e ss))
(sssetfirst nil ss))
(sssetfirst nil nil))
)
(defun PPDF-effective-name (obj / r)
(setq r
(vl-catch-all-apply
'(lambda ()
(if (vlax-property-available-p obj 'EffectiveName)
(vla-get-EffectiveName obj)
(vla-get-Name obj)))
'()))
(if (vl-catch-all-error-p r) nil r)
)
(defun PPDF-lwpoly-points (ename / pair points)
(foreach pair (entget ename)
(if (= (car pair) 10)
(setq points (cons (list (cadr pair) (caddr pair)) points))))
(reverse points)
)
(defun PPDF-point-in-poly-p (pt poly / i j inside a b px py ax ay bx by)
(setq i 0 j (1- (length poly)) inside nil px (car pt) py (cadr pt))
(while (< i (length poly))
(setq a (nth i poly) b (nth j poly)
ax (car a) ay (cadr a)
bx (car b) by (cadr b))
(if (and (/= ay by)
(or (and (<= ay py) (< py by))
(and (<= by py) (< py ay)))
(< px (+ ax (* (/ (- py ay) (- by ay)) (- bx ax)))))
(setq inside (not inside)))
(setq j i i (1+ i)))
inside
)
(defun PPDF-closed-lwpoly-p (ename / d flags)
(setq d (entget ename))
(if (not (and d (= (cdr (assoc 0 d)) "LWPOLYLINE")))
nil
(progn
(setq flags (cdr (assoc 70 d)))
(if (null flags) (setq flags 0))
(= 1 (logand 1 flags))))
)
;;; ------------------------------------------------------------
;;;  Проверка: LWPOLYLINE - это прямоугольник (RECTANG).
;;;  Условия: замкнута, ровно 4 вершины, все bulge = 0.
;;; ------------------------------------------------------------
(defun PPDF-rect-lwpoly-p (ename / d flags pts n bulge)
(setq d (entget ename))
(if (not (and d (= (cdr (assoc 0 d)) "LWPOLYLINE")))
nil
(progn
(setq flags (cdr (assoc 70 d)))
(if (null flags) (setq flags 0))
(setq pts nil bulge T)
(foreach pair d
(cond
((= (car pair) 10) (setq pts (cons (cdr pair) pts)))
((= (car pair) 42)
(if (/= (cdr pair) 0.0) (setq bulge nil)))))
(setq n (length pts))
(and (= 1 (logand 1 flags))
(= n 4)
bulge)))
)
;;; ------------------------------------------------------------
;;;  Универсальное получение окна печати по объекту.
;;;  INSERT     -> bbox блока
;;;  LWPOLYLINE -> bbox, если это прямоугольник (RECTANG)
;;;  иначе      -> nil
;;; ------------------------------------------------------------
(defun PPDF-get-print-window (ent / ed typ)
(setq ed (entget ent))
(setq typ (cdr (assoc 0 ed)))
(cond
((= typ "INSERT")     (PPDF-bbox ent))
((= typ "LWPOLYLINE")
(if (PPDF-rect-lwpoly-p ent)
(PPDF-bbox ent)
nil))
(T nil))
)
;;; ------------------------------------------------------------
;;;  Сбор блоков внутри замкнутой полилинии
;;; ------------------------------------------------------------
(defun PPDF-collect-inside-poly
(sampleEnt polyEnt / sampleObj sampleName pts ss index
ename obj bb cx cy frames)
(setq sampleObj (vlax-ename->vla-object sampleEnt))
(setq sampleName (strcase (PPDF-effective-name sampleObj)))
(setq pts (PPDF-lwpoly-points polyEnt))
(setq ss (ssget "X" '((0 . "INSERT") (67 . 0) (410 . "Model"))))
(setq frames nil)
(if (and ss sampleName pts (> (length pts) 2))
(progn
(setq index 0)
(repeat (sslength ss)
(setq ename (ssname ss index))
(setq index (1+ index))
(setq obj (vlax-ename->vla-object ename))
(if (= (strcase (PPDF-effective-name obj)) sampleName)
(progn
(setq bb (PPDF-bbox ename))
(if bb
(progn
(setq cx (/ (+ (car bb) (caddr bb)) 2.0)
cy (/ (+ (cadr bb) (cadddr bb)) 2.0))
(if (PPDF-point-in-poly-p (list cx cy) pts)
(setq frames (cons bb frames))))))))))
(reverse frames)
)
;;; ------------------------------------------------------------
;;;  Обзор папки / открытие
;;; ------------------------------------------------------------
(defun PPDF-choose-folder (start / shell folder path)
(setq path nil)
(setq shell
(vl-catch-all-apply
'(lambda () (vlax-create-object "Shell.Application")) '()))
(if (not (vl-catch-all-error-p shell))
(progn
(setq folder
(vl-catch-all-apply
'(lambda ()
(vlax-invoke-method shell 'BrowseForFolder 0
(PPDF-T "outpath") 0
(if (and start (/= start "")) start 0)))
'()))
(if (and folder (not (vl-catch-all-error-p folder)))
(setq path
(vl-catch-all-apply
'(lambda ()
(vlax-get-property
(vlax-get-property folder 'Self) 'Path))
'())))
(if (vl-catch-all-error-p path) (setq path nil))
(if (and folder (not (vl-catch-all-error-p folder)))
(vl-catch-all-apply '(lambda () (vlax-release-object folder)) '()))
(vl-catch-all-apply '(lambda () (vlax-release-object shell)) '())))
path
)
(defun PPDF-open-folder (path / p)
(if (and path (/= path ""))
(progn
(setq p (vl-string-translate "/" "\\" path))
(if (/= (substr p (strlen p)) "\\")
(setq p (strcat p "\\")))
(if (vl-file-directory-p p)
(startapp "explorer.exe" p)
(alert (strcat (PPDF-T "alert_folder_missing") p))))
(alert (PPDF-T "msg_folder_no")))
(princ)
)
;;; Открыть файл в ассоциированной программе.
(defun PPDF-open-file (path / sh ok)
(if (and path (/= path ""))
(progn
(setq ok (or (findfile path) (vl-file-systime path)))
(if ok
(progn
(setq sh (vl-catch-all-apply
'(lambda () (vlax-create-object "Shell.Application")) '()))
(if (not (vl-catch-all-error-p sh))
(progn
(vl-catch-all-apply
'(lambda ()
(vlax-invoke-method sh 'ShellExecute path "" "" "open" 1))
'())
(vl-catch-all-apply '(lambda () (vlax-release-object sh)) '()))
(startapp "cmd.exe"
(strcat "/c start \"\" \"" path "\"")))
T)
(progn
(alert (strcat (PPDF-T "alert_file_missing") path))
nil)))
(progn
(alert (PPDF-T "alert_path_not_set"))
nil))
)
;;; ------------------------------------------------------------
;;;  Имена файлов и нумерация
;;; ------------------------------------------------------------
(defun PPDF-file-prefix (prefix suffix / s)
(setq s prefix)
(if (and suffix (/= suffix ""))
(setq s (strcat s "_" suffix)))
s
)
(defun PPDF-max-existing
(folder prefix suffix / files fname base key rest num maxn)
(setq maxn 0)
(setq key (PPDF-file-prefix prefix suffix))
(setq files (vl-directory-files folder "*.pdf" 1))
(foreach fname files
(setq base (vl-filename-base fname))
(if (and (> (strlen base) (+ (strlen key) 1))
(= (substr base 1 (strlen key)) key)
(= (substr base (1+ (strlen key)) 1) "_"))
(progn
(setq rest (substr base (+ (strlen key) 2)))
(setq num (atoi rest))
(if (> num maxn) (setq maxn num)))))
maxn
)
(defun PPDF-center-x (a) (/ (+ (car a) (caddr a)) 2.0))
(defun PPDF-center-y (a) (/ (+ (cadr a) (cadddr a)) 2.0))
(defun PPDF-sort-rows (lst / avgH tolerance)
(if (> (length lst) 1)
(progn
(setq avgH
(/ (apply '+
(mapcar '(lambda (x) (abs (- (cadddr x) (cadr x)))) lst))
(float (length lst))))
(if (<= avgH 0.0) (setq avgH 1.0))
(setq tolerance (* avgH 0.55))
(vl-sort lst
'(lambda (a b)
(if (<= (abs (- (PPDF-center-y a) (PPDF-center-y b))) tolerance)
(< (PPDF-center-x a) (PPDF-center-x b))
(> (PPDF-center-y a) (PPDF-center-y b))))))
lst))
(defun PPDF-sort-cols (lst / avgW tolerance)
(if (> (length lst) 1)
(progn
(setq avgW
(/ (apply '+
(mapcar '(lambda (x) (abs (- (caddr x) (car x)))) lst))
(float (length lst))))
(if (<= avgW 0.0) (setq avgW 1.0))
(setq tolerance (* avgW 0.55))
(vl-sort lst
'(lambda (a b)
(if (<= (abs (- (PPDF-center-x a) (PPDF-center-x b))) tolerance)
(> (PPDF-center-y a) (PPDF-center-y b))
(< (PPDF-center-x a) (PPDF-center-x b))))))
lst))
(defun PPDF-sort-frames (lst mode)
(if (= mode "C") (PPDF-sort-cols lst) (PPDF-sort-rows lst))
)
;;; ------------------------------------------------------------
;;;  Выборочный набор (блоки + прямоугольники RECTANG)
;;; ------------------------------------------------------------
(defun PPDF-select-blocks ( / sel ent entdata picked counter continue)
(setq picked nil counter 0 continue T)
(princ (PPDF-T "pr_sel_header"))
(princ (PPDF-T "pr_sel_hint"))
(while continue
(initget "C")
(setq sel
(entsel (strcat (PPDF-T "pr_sel_picked")
(itoa counter)
(PPDF-T "pr_sel_prompt"))))
(cond
((null sel) (setq continue nil) (PPDF-highlight nil))
((= (type sel) 'STR)
(if (= sel "C")
(if picked
(progn
(setq picked (vl-remove (last picked) picked))
(setq counter (length picked))
(PPDF-highlight picked)
(princ (strcat (PPDF-T "pr_sel_undone")
(itoa counter))))
(princ (PPDF-T "pr_sel_nothing")))))
(T
(setq ent (car sel) entdata (entget ent))
(cond
((null (PPDF-get-print-window ent))
(princ (PPDF-T "pr_sel_bad")))
((member ent picked)
(setq picked (vl-remove ent picked)
counter (length picked))
(PPDF-highlight picked)
(princ (strcat (PPDF-T "pr_sel_removed")
(itoa counter))))
(T
(setq picked (append picked (list ent))
counter (length picked))
(PPDF-highlight picked)
(princ (strcat (PPDF-T "pr_sel_added")
(itoa counter))))))))
picked
)
;;; ------------------------------------------------------------
;;;  Восстановление Layout
;;; ------------------------------------------------------------
(defun PPDF-restore-layout
(layout config media rotation styleSheet plotType withStyles)
(if (and layout config (/= config ""))
(PPDF-safe-put-property layout 'ConfigName config))
(if (PPDF-refresh-layout layout)
(progn
(if (and media (/= media ""))
(PPDF-safe-put-property layout 'CanonicalMediaName media))
(if rotation
(PPDF-safe-put-property layout 'PlotRotation rotation))
(if plotType
(PPDF-safe-put-property layout 'PlotType plotType))
(if withStyles
(PPDF-safe-put-property layout 'PlotWithPlotStyles :vlax-true)
(PPDF-safe-put-property layout 'PlotWithPlotStyles :vlax-false))
(if (and styleSheet (/= styleSheet ""))
(PPDF-safe-put-property layout 'StyleSheet styleSheet))))
(princ)
)
;;; ============================================================
;;;  ЗАПУСК PDFTK
;;; ============================================================
(defun PPDF-find-pdftk ( / p)
(setq p (findfile "pdftk.exe"))
(if p p
(progn
(alert (PPDF-T "alert_pdftk_missing"))
nil))
)
(defun PPDF-run-sync (cmd / wsh wrapped raw rc)
(setq wrapped (strcat "cmd.exe /c \"" cmd "\""))
(setq wsh (vl-catch-all-apply
'(lambda () (vlax-create-object "WScript.Shell")) '()))
(if (vl-catch-all-error-p wsh)
(progn
(princ (strcat "
[PPDF] WScript.Shell unavailable: "
(vl-catch-all-error-message wsh)))
-1)
(progn
(setq raw
(vl-catch-all-apply
'(lambda ()
(vlax-invoke-method wsh 'Run wrapped 0 :vlax-true))
'()))
(cond
((vl-catch-all-error-p raw)
(princ (strcat "
[PPDF] Run error: "
(vl-catch-all-error-message raw)))
(setq rc -1))
((null raw) (setq rc -1))
(T
(setq rc (vl-catch-all-apply
'(lambda () (vlax-variant-value raw)) '()))
(if (vl-catch-all-error-p rc) (setq rc -1))))
(vl-catch-all-apply '(lambda () (vlax-release-object wsh)) '())
rc))
)
;;; ============================================================
;;;  ОБЪЕДИНЕНИЕ PDF
;;; ============================================================
(defun PPDF-build-pdftk-cmd (pdftk fileList tmpFile errFile outFile / cmd)
(setq cmd (strcat "\"" pdftk "\""))
(foreach fl fileList
(setq cmd (strcat cmd " \"" fl "\"")))
(setq cmd (strcat cmd
" cat output \"" tmpFile "\""
" >\"" outFile "\""
" 2>\"" errFile "\""))
cmd
)
(defun PPDF-read-file (path / f line acc)
(setq acc "")
(if (vl-file-systime path)
(progn
(setq f (open path "r"))
(if f
(progn
(while (setq line (read-line f))
(setq acc (strcat acc line "
")))
(close f)))))
acc
)
(defun PPDF-do-merge
(fileList outPath mergedName action prefix suffix
/ pdftk cmd tmpFile errFile outFile rc ok errTxt total i
mergedDir src dst base ts)
(if (or (null fileList) (< (length fileList) 1))
(progn (alert (PPDF-T "alert_no_files_merge")) nil)
(if (not (setq pdftk (PPDF-find-pdftk)))
nil
(progn
(setq tmpFile (strcat outPath "\\" mergedName))
(if (member tmpFile fileList)
(setq tmpFile
(strcat outPath "\\" (vl-filename-base mergedName)
"_out.pdf")))
(setq errFile (strcat outPath "\\_ppdf_pdftk_err.txt")
outFile (strcat outPath "\\_ppdf_pdftk_out.txt")
total   (length fileList))
(if (vl-file-systime errFile) (vl-file-delete errFile))
(if (vl-file-systime outFile) (vl-file-delete outFile))
(if (vl-file-systime tmpFile) (vl-file-delete tmpFile))
(setq cmd (PPDF-build-pdftk-cmd
pdftk fileList tmpFile errFile outFile))
(princ (strcat (PPDF-T "pr_merge_running")
(itoa total)
(PPDF-T "pr_merge_files")))
(grtext -1 (strcat "PPDF: "
(itoa total)
(PPDF-T "pr_merge_files")))
(setq rc (PPDF-run-sync cmd))
(grtext -1 "")
(setq ok (vl-file-systime tmpFile))
(if ok
(progn
(cond
((= action "DELETE")
(foreach fl fileList
(if (not (vl-file-delete fl))
(princ (strcat (PPDF-T "pr_delete_fail") fl))))
(princ (strcat (PPDF-T "pr_merge_deleted")
(itoa total)
(PPDF-T "pr_merge_files"))))
((= action "ARCHIVE")
(setq ts (PPDF-timestamp))
(setq mergedDir
(PPDF-unique-dir outPath (strcat ts "_merged")))
(if (not (vl-file-directory-p mergedDir))
(vl-mkdir mergedDir))
(foreach fl fileList
(setq src fl
dst (strcat mergedDir (vl-filename-base fl) ".pdf"))
(if (vl-file-systime dst)
(setq dst (strcat mergedDir
(vl-filename-base fl)
"_" ts ".pdf")))
(if (not (PPDF-move-file src dst))
(princ (strcat (PPDF-T "pr_move_fail") fl))))
(princ (strcat (PPDF-T "pr_merge_archived") mergedDir))))
(if (vl-file-systime errFile) (vl-file-delete errFile))
(if (vl-file-systime outFile) (vl-file-delete outFile))
tmpFile)
(progn
(setq errTxt (PPDF-read-file errFile))
(if (vl-file-systime errFile) (vl-file-delete errFile))
(if (vl-file-systime outFile) (vl-file-delete outFile))
(alert
(strcat
(PPDF-T "alert_pdftk_failed_1")
(itoa rc)
(PPDF-T "alert_pdftk_failed_2")
(if (= errTxt "")
(PPDF-T "alert_empty_stderr")
errTxt)
(PPDF-T "alert_pdftk_failed_3")))
nil)))))
)
;;; ------------------------------------------------------------
;;;  Сбор файлов для объединения
;;; ------------------------------------------------------------
(defun PPDF-collect-rec (dir mask acc / fl sd)
(setq fl (vl-directory-files dir mask 1))
(foreach f fl
(if (and (not (wcmatch (strcase dir) "*_MERGED*"))
(not (wcmatch (strcase dir) "*_ARCHIVE*")))
(setq acc (cons (strcat dir "\\" f) acc))))
(setq sd (vl-directory-files dir "*" -1))
(foreach d sd
(if (and (/= d ".") (/= d "..")
(not (wcmatch (strcase d) "*_MERGED*"))
(not (wcmatch (strcase d) "*_ARCHIVE*")))
(setq acc (PPDF-collect-rec (strcat dir "\\" d) mask acc))))
acc
)
(defun PPDF-get-merge-files
(mode outpath prefix suffix lastSession / mask files)
(cond
((= mode "SESSION")
(if lastSession (cdr (assoc 'files lastSession)) nil))
((= mode "FOLDER")
(setq mask (strcat (PPDF-file-prefix prefix suffix) "_*.pdf"))
(setq files (vl-directory-files outpath mask 1))
(if files
(mapcar '(lambda (f) (strcat outpath "\\" f)) files)
nil))
((= mode "GLOBAL")
(setq mask (strcat (PPDF-file-prefix prefix suffix) "_*.pdf"))
(reverse (PPDF-collect-rec outpath mask nil)))
(T nil))
)
;;; ============================================================
;;;  Обработчики главного диалога
;;; ============================================================
(defun PPDF-DLG-plotter-change
( / idx plt ml canon locale newCanon newIdx i)
(setq idx (atoi (get_tile "plotter")))
(setq plt (nth idx PPDF-DLG-plotterList))
(if (and plt (/= plt ""))
(if (PPDF-safe-put-property PPDF-DLG-layout 'ConfigName plt)
(progn
(PPDF-refresh-layout PPDF-DLG-layout)
(setq ml (PPDF-get-media-lists PPDF-DLG-layout))
(if ml
(progn
(setq PPDF-DLG-mediaLists ml)
(setq canon  (car ml)
locale (cadr ml))
(start_list "paper")
(foreach m locale (add_list m))
(end_list)
(setq newIdx (vl-position PPDF-DLG-paperCanon canon))
(if (null newIdx)
(progn
(setq newCanon (PPDF-agree-media PPDF-DLG-paperCanon canon))
(setq newIdx (cond ((setq i (vl-position newCanon canon)) i)
(T 0)))
(setq PPDF-DLG-paperCanon (nth newIdx canon))))
(setq PPDF-DLG-paperIdx newIdx)
(set_tile "paper" (itoa newIdx)))))))
)
(defun PPDF-DLG-read-tiles ( / idx ml)
(setq ml PPDF-DLG-mediaLists)
(setq PPDF-DLG-prefix    (get_tile "prefix"))
(setq PPDF-DLG-suffix    (get_tile "suffix"))
(setq PPDF-DLG-outpath   (get_tile "outpath"))
(setq PPDF-DLG-scaleStr  (get_tile "scale"))
(setq PPDF-DLG-styleName (nth (atoi (get_tile "style"))
PPDF-DLG-styleList))
(setq idx (atoi (get_tile "paper")))
(if (or (null ml) (< idx (length (car ml))))
(progn
(setq PPDF-DLG-paperIdx (if (null ml) 0 idx))
(setq PPDF-DLG-paperCanon (if (null ml) "" (nth idx (car ml))))))
(setq PPDF-DLG-plotterCfg (nth (atoi (get_tile "plotter"))
PPDF-DLG-plotterList))
(setq PPDF-DLG-orientCfg (if (= (get_tile "orient_landscape") "1")
"Landscape" "Portrait"))
(setq PPDF-DLG-plotMode  (cond
((= (get_tile "mode_all")  "1") "A")
((= (get_tile "mode_one")  "1") "1")
((= (get_tile "mode_poly") "1") "P")
(T "S")))
(setq PPDF-DLG-sortMode  (if (= (get_tile "sort_cols") "1") "C" "R"))
(setq PPDF-DLG-mergeAfter (if (= (get_tile "merge_after") "1") "1" "0"))
(setq PPDF-DLG-langCfg
(if (= (atoi (get_tile "lang")) 1) "EN" "RU"))
)
;;; В CFG сохраняются ТОЛЬКО настройки главного окна + язык.
;;; mergeName не сохраняется - он всегда пересобирается.
;;; mergeMode и mergeAction сохраняются отдельно после слияния.
(defun PPDF-DLG-build-cfg ( / )
(list
(cons "prefix"     PPDF-DLG-prefix)
(cons "suffix"     PPDF-DLG-suffix)
(cons "outpath"    PPDF-DLG-outpath)
(cons "styleName"  PPDF-DLG-styleName)
(cons "paperName"  PPDF-DLG-paperCanon)
(cons "plotter"    PPDF-DLG-plotterCfg)
(cons "orient"     PPDF-DLG-orientCfg)
(cons "scaleStr"   PPDF-DLG-scaleStr)
(cons "plotMode"   PPDF-DLG-plotMode)
(cons "sortMode"   PPDF-DLG-sortMode)
(cons "mergeAfter" PPDF-DLG-mergeAfter)
(cons "lang"       PPDF-DLG-langCfg))
)
(defun PPDF-DLG-save-cfg ( / cfg newCfg)
(PPDF-DLG-read-tiles)
(setq cfg (PPDF-load-cfg))
(setq newCfg (PPDF-DLG-build-cfg))
(foreach kv newCfg
(setq cfg (PPDF-cfg-set cfg (car kv) (cdr kv))))
(if (PPDF-save-cfg cfg)
(alert (PPDF-T "msg_cfg_saved"))
(alert (PPDF-T "msg_cfg_failed")))
(done_dialog 4)
)
(defun PPDF-DLG-do-print ( / cfg newCfg)
(PPDF-DLG-read-tiles)
(setq cfg (PPDF-load-cfg))
(setq newCfg (PPDF-DLG-build-cfg))
(foreach kv newCfg
(setq cfg (PPDF-cfg-set cfg (car kv) (cdr kv))))
(PPDF-save-cfg cfg)
(done_dialog 1)
)
;;; Язык поменялся в выпадашке LNG:
;;;   - запоминаем его в *PPDF-LANG* и в CFG;
;;;   - закрываем диалог кодом 7.
;;; Главный цикл увидит 7, перерисует DCL и снова откроет окно
;;; уже с новым языком.
(defun PPDF-DLG-lang-change ( / cfg newCfg)
(setq *PPDF-LANG*
(if (= (atoi (get_tile "lang")) 1) "EN" "RU"))
(PPDF-DLG-read-tiles)
(setq PPDF-DLG-langCfg *PPDF-LANG*)
(setq cfg (PPDF-load-cfg))
(setq newCfg (PPDF-DLG-build-cfg))
(foreach kv newCfg
(setq cfg (PPDF-cfg-set cfg (car kv) (cdr kv))))
(PPDF-save-cfg cfg)
(done_dialog 7)
)
;;; ============================================================
;;;  Хелпер аварийного выхода
;;; ============================================================
(defun PPDF-abort (alayout originalPlotter originalMedia originalRotation
originalStyleSheet originalPlotType originalWithStyles
oldBgPlot oldCmdecho oldError msg)
(PPDF-restore-layout alayout originalPlotter originalMedia
originalRotation originalStyleSheet originalPlotType originalWithStyles)
(if oldBgPlot  (setvar "BACKGROUNDPLOT" oldBgPlot))
(if oldCmdecho (setvar "CMDECHO" oldCmdecho))
(if msg (alert msg))
(setq *error* oldError)
(princ)
(exit)
)
;;; ============================================================
;;;  Главная команда
;;; ============================================================
(defun c:PPDF ( /
cfg adoc acad alayout aplot
styleList plotterList filteredPlotterList
mediaLists canonList localeList
prefix suffix outpath
styleName paperCanon paperIdx
plotterCfg
orientCfg scaleStr plotMode sortMode mergeAfter
mergeMode mergeAction langCfg
useFit scaleVal styleSheet paperSize
dcl_id dResult
frameList counter i ent ss sel
pt1 pt2 fname
pickedList p
originalPlotter originalMedia originalRotation
originalStyleSheet originalPlotType originalWithStyles
currentPlotter blockName
sampleEnt polyEnt
oldBgPlot oldCmdecho
oldError
*error* errMsg
printedFiles doneRes mergeParams mergedResult lastSession
defaultMergeName
)
(vl-load-com)
(setq oldError *error*)
(defun *error* (msg)
(if oldBgPlot  (setvar "BACKGROUNDPLOT" oldBgPlot))
(if oldCmdecho (setvar "CMDECHO" oldCmdecho))
(if (and alayout originalPlotter)
(PPDF-restore-layout alayout
originalPlotter originalMedia originalRotation
originalStyleSheet originalPlotType originalWithStyles))
(grtext -1 "")
(if (and msg
(not (wcmatch (strcase msg)
"*CANCEL*,*QUIT*,*EXIT*")))
(princ (strcat "
PPDF error: " msg))
(princ "
PPDF interrupted."))
(setq *error* oldError)
(princ)
)
(setq oldBgPlot  (getvar "BACKGROUNDPLOT"))
(setq oldCmdecho (getvar "CMDECHO"))
(setq acad (vl-catch-all-apply
'(lambda () (vlax-get-acad-object)) '()))
(if (vl-catch-all-error-p acad)
(PPDF-abort nil nil nil nil nil nil nil oldBgPlot oldCmdecho oldError
(PPDF-T "msg_err_autocad")))
(setq adoc (vl-catch-all-apply
'(lambda () (vla-get-ActiveDocument acad)) '()))
(if (vl-catch-all-error-p adoc)
(PPDF-abort nil nil nil nil nil nil nil oldBgPlot oldCmdecho oldError
(PPDF-T "msg_err_doc")))
(setq alayout (vl-catch-all-apply
'(lambda () (vla-get-ActiveLayout adoc)) '()))
(if (vl-catch-all-error-p alayout)
(PPDF-abort nil nil nil nil nil nil nil oldBgPlot oldCmdecho oldError
(PPDF-T "msg_err_layout")))
(setq aplot (vl-catch-all-apply
'(lambda () (vla-get-Plot adoc)) '()))
(if (vl-catch-all-error-p aplot)
(PPDF-abort alayout nil nil nil nil nil nil oldBgPlot oldCmdecho oldError
(PPDF-T "msg_err_plot")))
(setq originalPlotter    (PPDF-safe-get-property alayout 'ConfigName))
(setq originalMedia      (PPDF-safe-get-property alayout 'CanonicalMediaName))
(setq originalRotation   (PPDF-safe-get-property alayout 'PlotRotation))
(setq originalStyleSheet (PPDF-safe-get-property alayout 'StyleSheet))
(setq originalPlotType   (PPDF-safe-get-property alayout 'PlotType))
(setq originalWithStyles (PPDF-safe-get-property alayout 'PlotWithPlotStyles))
(PPDF-refresh-layout alayout)
(setq cfg (PPDF-load-cfg))
(setq prefix      (cdr (assoc "prefix"      cfg)))
(setq suffix      (cdr (assoc "suffix"      cfg)))
(setq outpath     (cdr (assoc "outpath"     cfg)))
(setq styleName   (cdr (assoc "styleName"   cfg)))
(setq paperCanon  (cdr (assoc "paperName"   cfg)))
(setq plotterCfg  (cdr (assoc "plotter"     cfg)))
(setq orientCfg   (cdr (assoc "orient"      cfg)))
(setq scaleStr    (cdr (assoc "scaleStr"    cfg)))
(setq plotMode    (cdr (assoc "plotMode"    cfg)))
(setq sortMode    (cdr (assoc "sortMode"    cfg)))
(setq mergeAfter  (cdr (assoc "mergeAfter"  cfg)))
(setq mergeMode   (cdr (assoc "mergeMode"   cfg)))
(setq mergeAction (cdr (assoc "mergeAction" cfg)))
(setq langCfg     (cdr (assoc "lang"        cfg)))
(if (or (null mergeMode)   (= mergeMode ""))   (setq mergeMode   "SESSION"))
(if (or (null mergeAction) (= mergeAction "")) (setq mergeAction "ARCHIVE"))
(if (or (null langCfg)     (= langCfg ""))     (setq langCfg     "RU"))
(setq *PPDF-LANG* langCfg)
(setq styleList   (PPDF-get-style-list alayout))
(setq plotterList (PPDF-get-plotter-list alayout))
(if (null plotterList)
(PPDF-abort alayout originalPlotter originalMedia originalRotation
originalStyleSheet originalPlotType originalWithStyles
oldBgPlot oldCmdecho oldError
(PPDF-T "msg_err_plotters")))
(setq filteredPlotterList (PPDF-only-pdf-plotters plotterList))
(if filteredPlotterList
(setq plotterList filteredPlotterList)
(princ "
[PPDF] DWG To PDF* not found, showing all."))
(setq currentPlotter originalPlotter)
(if (or (null currentPlotter) (= currentPlotter "")
(not (member currentPlotter plotterList)))
(setq currentPlotter (car plotterList)))
(if (and currentPlotter originalPlotter
(/= currentPlotter originalPlotter))
(progn
(PPDF-safe-put-property alayout 'ConfigName currentPlotter)
(PPDF-refresh-layout alayout)))
(setq mediaLists (PPDF-get-media-lists alayout))
(setq canonList  (car mediaLists))
(setq localeList (cadr mediaLists))
(if (or (null canonList) (= (length canonList) 0))
(PPDF-abort alayout originalPlotter originalMedia originalRotation
originalStyleSheet originalPlotType originalWithStyles
oldBgPlot oldCmdecho oldError
(PPDF-T "msg_err_media")))
(if (not (member plotterCfg plotterList))
(setq plotterCfg currentPlotter))
(setq paperIdx (vl-position paperCanon canonList))
(if (null paperIdx)
(progn
(setq paperCanon (PPDF-agree-media paperCanon canonList))
(setq paperIdx (cond ((setq p (vl-position paperCanon canonList)) p) (T 0)))
(setq paperCanon (nth paperIdx canonList))))
(if (not (PPDF-write-dcl))
(PPDF-abort alayout originalPlotter originalMedia originalRotation
originalStyleSheet originalPlotType originalWithStyles
oldBgPlot oldCmdecho oldError
(PPDF-T "msg_err_dcl")))
(setq dResult 2)
(while (>= dResult 2)
(setq dcl_id (load_dialog (PPDF-dclpath)))
(if (< dcl_id 0)
(PPDF-abort alayout originalPlotter originalMedia originalRotation
originalStyleSheet originalPlotType originalWithStyles
oldBgPlot oldCmdecho oldError
(PPDF-T "msg_err_dcl_load")))
(if (not (new_dialog "ppdf_dialog" dcl_id))
(progn
(unload_dialog dcl_id)
(PPDF-abort alayout originalPlotter originalMedia originalRotation
originalStyleSheet originalPlotType originalWithStyles
oldBgPlot oldCmdecho oldError
(PPDF-T "msg_err_dlg"))))
(setq PPDF-DLG-layout        alayout)
(setq PPDF-DLG-styleList     styleList)
(setq PPDF-DLG-plotterList   plotterList)
(setq PPDF-DLG-mediaLists    mediaLists)
(setq PPDF-DLG-paperCanon    paperCanon)
(setq PPDF-DLG-paperIdx      paperIdx)
(set_tile "prefix" (if prefix prefix "frame"))
(set_tile "suffix" (if suffix suffix ""))
(set_tile "outpath"
(if (and outpath (/= outpath ""))
outpath
(strcat (getenv "USERPROFILE") "\\Desktop")))
(set_tile "scale" (if scaleStr scaleStr ""))
(set_tile "merge_after" (if (equal mergeAfter "0") "0" "1"))
;; Заполнить выпадашку языков и выставить текущий
(start_list "lang")
(add_list "RU")
(add_list "EN")
(end_list)
(set_tile "lang" (if (= *PPDF-LANG* "EN") "1" "0"))
(cond
((= plotMode "A") (set_tile "mode_all"  "1"))
((= plotMode "1") (set_tile "mode_one"  "1"))
((= plotMode "P") (set_tile "mode_poly" "1"))
(T                (set_tile "mode_sel"  "1")))
(start_list "style")
(foreach s styleList (add_list s))
(end_list)
(set_tile "style"
(itoa (cond ((setq p (vl-position styleName styleList)) p) (T 0))))
(start_list "paper")
(foreach item localeList (add_list item))
(end_list)
(set_tile "paper" (itoa paperIdx))
(start_list "plotter")
(foreach s plotterList (add_list s))
(end_list)
(set_tile "plotter"
(itoa (cond ((setq p (vl-position plotterCfg plotterList)) p) (T 0))))
(if (= orientCfg "Landscape")
(set_tile "orient_landscape" "1")
(set_tile "orient_portrait"  "1"))
(if (= sortMode "C")
(set_tile "sort_cols" "1")
(set_tile "sort_rows" "1"))
(action_tile "show_help"    "(done_dialog 6)")
(action_tile "click_folder" "(done_dialog 3)")
(action_tile "open_folder"  "(done_dialog 5)")
(action_tile "plotter"      "(PPDF-DLG-plotter-change)")
(action_tile "save_cfg"     "(PPDF-DLG-save-cfg)")
(action_tile "do_print"     "(PPDF-DLG-do-print)")
(action_tile "lang"         "(PPDF-DLG-lang-change)")
(setq dResult (start_dialog))
(unload_dialog dcl_id)
(setq prefix      PPDF-DLG-prefix)
(setq suffix      PPDF-DLG-suffix)
(setq outpath     PPDF-DLG-outpath)
(setq scaleStr    PPDF-DLG-scaleStr)
(setq styleName   PPDF-DLG-styleName)
(setq paperCanon  PPDF-DLG-paperCanon)
(setq paperIdx    PPDF-DLG-paperIdx)
(setq plotterCfg  PPDF-DLG-plotterCfg)
(setq orientCfg   PPDF-DLG-orientCfg)
(setq plotMode    PPDF-DLG-plotMode)
(setq sortMode    PPDF-DLG-sortMode)
(setq mergeAfter  PPDF-DLG-mergeAfter)
(setq mediaLists  PPDF-DLG-mediaLists)
(setq canonList   (car mediaLists))
(setq localeList  (cadr mediaLists))
(if (/= dResult 1)
(if (and alayout originalPlotter
(not (equal (PPDF-safe-get-property alayout 'ConfigName)
originalPlotter)))
(progn
(PPDF-safe-put-property alayout 'ConfigName originalPlotter)
(PPDF-refresh-layout alayout))))
(cond
((= dResult 3)
(setq sel (PPDF-choose-folder outpath))
(if (and sel (/= sel "")) (setq outpath sel))
(setq dResult 2))
((= dResult 5) (PPDF-open-folder outpath) (setq dResult 2))
((= dResult 4) (setq dResult 2))
((= dResult 6) (PPDF-show-help) (setq dResult 2))
((= dResult 7)
;; Перезапуск главного цикла с новым языком.
(PPDF-write-dcl)
(setq dResult 2))))
(if (or (= dResult 0) (= dResult -1))
(progn
(PPDF-restore-layout alayout originalPlotter originalMedia
originalRotation originalStyleSheet originalPlotType originalWithStyles)
(if oldBgPlot  (setvar "BACKGROUNDPLOT" oldBgPlot))
(if oldCmdecho (setvar "CMDECHO" oldCmdecho))
(setq *error* oldError)
(princ (strcat "
" (PPDF-T "msg_canceled"))) (princ) (exit)))
(if (or (null outpath) (= outpath ""))
(setq outpath (strcat (getenv "USERPROFILE") "\\Desktop")))
(setq outpath (vl-string-translate "/" "\\" outpath))
(if (/= (substr outpath (strlen outpath)) "\\")
(setq outpath (strcat outpath "\\")))
(if (not (vl-file-directory-p outpath)) (vl-mkdir outpath))
(if (not (PPDF-preflight-check outpath))
(progn
(PPDF-restore-layout alayout originalPlotter originalMedia
originalRotation originalStyleSheet originalPlotType originalWithStyles)
(setq *error* oldError)
(princ (strcat "
" (PPDF-T "msg_preflight_no"))) (princ) (exit)))
(if (or (= scaleStr "") (= scaleStr "0")
(= (strcase scaleStr) "F") (= (strcase scaleStr) "FIT"))
(progn (setq useFit T) (setq scaleVal 0.0))
(progn
(setq useFit nil)
(setq scaleVal (atof scaleStr))
(if (<= scaleVal 0.0) (setq useFit T))))
(setq styleSheet
(if (or (= styleName "") (= styleName "None (Color)"))
"" styleName))
(setvar "BACKGROUNDPLOT" 0)
(setvar "CMDECHO" 0)
(if (not (PPDF-safe-put-property alayout 'ConfigName plotterCfg))
(PPDF-abort alayout originalPlotter originalMedia originalRotation
originalStyleSheet originalPlotType originalWithStyles
oldBgPlot 1 oldError
(strcat (PPDF-T "msg_plot_set_err") plotterCfg)))
(PPDF-refresh-layout alayout)
(setq mediaLists (PPDF-get-media-lists alayout))
(setq canonList  (car mediaLists))
(setq localeList (cadr mediaLists))
(if (or (null canonList) (= (length canonList) 0))
(PPDF-abort alayout originalPlotter originalMedia originalRotation
originalStyleSheet originalPlotType originalWithStyles
oldBgPlot 1 oldError
(strcat (PPDF-T "alert_paper_fail_pre") plotterCfg)))
(setq paperIdx (vl-position paperCanon canonList))
(if (null paperIdx)
(progn
(setq paperSize (PPDF-agree-media paperCanon canonList))
(setq paperIdx (cond ((setq p (vl-position paperSize canonList)) p) (T 0)))
(setq paperCanon paperSize)))
(setq paperSize (nth paperIdx canonList))
(if (/= paperSize paperCanon)
(princ (strcat "
[PPDF] "
(PPDF-T "pr_paper")
" '"
paperCanon
(PPDF-T "msg_paper_fallback")
paperSize
"'.")))
(setq paperCanon paperSize)
(if (not (PPDF-safe-put-property alayout 'CanonicalMediaName paperCanon))
(PPDF-abort alayout originalPlotter originalMedia originalRotation
originalStyleSheet originalPlotType originalWithStyles
oldBgPlot 1 oldError
(strcat (PPDF-T "msg_paper_set_err") paperCanon)))
(if (= orientCfg "Landscape")
(PPDF-safe-put-property alayout 'PlotRotation 0)
(PPDF-safe-put-property alayout 'PlotRotation 1))
(PPDF-safe-put-property alayout 'CenterPlot         :vlax-true)
(PPDF-safe-put-property alayout 'PlotWithLineweights :vlax-true)
(if (/= styleSheet "")
(progn
(PPDF-safe-put-property alayout 'PlotWithPlotStyles :vlax-true)
(if (not (PPDF-safe-put-property alayout 'StyleSheet styleSheet))
(princ (strcat "
[!] Could not set style: " styleSheet))))
(PPDF-safe-put-property alayout 'PlotWithPlotStyles :vlax-false))
(if useFit
(progn
(PPDF-safe-put-property alayout 'UseStandardScale :vlax-true)
(PPDF-safe-put-property alayout 'StandardScale 0))
(progn
(PPDF-safe-put-property alayout 'UseStandardScale :vlax-false)
(PPDF-safe-invoke alayout 'SetCustomScale (list 1.0 scaleVal))))
(PPDF-safe-put-property alayout 'PlotType 4)
(setq frameList nil counter 0 printedFiles nil)
(cond
((= plotMode "S")
(setq pickedList (PPDF-select-blocks))
(if (or (null pickedList) (= (length pickedList) 0))
(PPDF-abort alayout originalPlotter originalMedia originalRotation
originalStyleSheet originalPlotType originalWithStyles
oldBgPlot 1 oldError (PPDF-T "msg_no_frames")))
(foreach e pickedList
(setq p (PPDF-get-print-window e))
(if p (setq frameList (append frameList (list p)))))
(setq counter (length frameList)))
((= plotMode "1")
(princ (PPDF-T "pr_one_header"))
(princ (PPDF-T "pr_one_prompt"))
(setq sel (entsel ""))
(if (null sel)
(PPDF-abort alayout originalPlotter originalMedia originalRotation
originalStyleSheet originalPlotType originalWithStyles
oldBgPlot 1 oldError (PPDF-T "msg_canceled")))
(setq ent (car sel))
(setq p (PPDF-get-print-window ent))
(if (null p)
(PPDF-abort alayout originalPlotter originalMedia originalRotation
originalStyleSheet originalPlotType originalWithStyles
oldBgPlot 1 oldError (PPDF-T "msg_err_rect")))
(setq frameList (list p))
(setq counter (length frameList)))
((= plotMode "A")
(princ (PPDF-T "pr_all_header"))
(princ (PPDF-T "pr_all_prompt"))
(setq sel (entsel ""))
(if (null sel)
(PPDF-abort alayout originalPlotter originalMedia originalRotation
originalStyleSheet originalPlotType originalWithStyles
oldBgPlot 1 oldError (PPDF-T "msg_canceled")))
(setq ent (car sel))
(if (/= (cdr (assoc 0 (entget ent))) "INSERT")
(PPDF-abort alayout originalPlotter originalMedia originalRotation
originalStyleSheet originalPlotType originalWithStyles
oldBgPlot 1 oldError (PPDF-T "msg_err_block")))
(setq blockName (strcase (PPDF-effective-name
(vlax-ename->vla-object ent))))
(setq ss (ssget "X" '((0 . "INSERT") (67 . 0) (410 . "Model"))))
(setq frameList nil)
(if ss
(progn
(setq i 0)
(repeat (sslength ss)
(setq ent (ssname ss i))
(setq i (1+ i))
(if (= (strcase (PPDF-effective-name
(vlax-ename->vla-object ent)))
blockName)
(progn
(setq p (PPDF-bbox ent))
(if p (setq frameList (append frameList (list p)))))))))
(if (null frameList)
(PPDF-abort alayout originalPlotter originalMedia originalRotation
originalStyleSheet originalPlotType originalWithStyles
oldBgPlot 1 oldError (PPDF-T "msg_blocks_not_found")))
(setq counter (length frameList)))
((= plotMode "P")
(princ (PPDF-T "pr_poly_header"))
(princ (PPDF-T "pr_poly_sample"))
(setq sel (entsel ""))
(if (null sel)
(PPDF-abort alayout originalPlotter originalMedia originalRotation
originalStyleSheet originalPlotType originalWithStyles
oldBgPlot 1 oldError (PPDF-T "msg_sample_no")))
(setq sampleEnt (car sel))
(if (/= (cdr (assoc 0 (entget sampleEnt))) "INSERT")
(PPDF-abort alayout originalPlotter originalMedia originalRotation
originalStyleSheet originalPlotType originalWithStyles
oldBgPlot 1 oldError (PPDF-T "msg_err_block")))
(princ (PPDF-T "pr_poly_prompt"))
(setq sel (entsel ""))
(if (null sel)
(PPDF-abort alayout originalPlotter originalMedia originalRotation
originalStyleSheet originalPlotType originalWithStyles
oldBgPlot 1 oldError (PPDF-T "msg_poly_no")))
(setq polyEnt (car sel))
(if (not (PPDF-closed-lwpoly-p polyEnt))
(PPDF-abort alayout originalPlotter originalMedia originalRotation
originalStyleSheet originalPlotType originalWithStyles
oldBgPlot 1 oldError (PPDF-T "msg_err_poly")))
(setq frameList (PPDF-collect-inside-poly sampleEnt polyEnt))
(if (or (null frameList) (= (length frameList) 0))
(PPDF-abort alayout originalPlotter originalMedia originalRotation
originalStyleSheet originalPlotType originalWithStyles
oldBgPlot 1 oldError (PPDF-T "msg_err_inside")))
(setq counter (length frameList))))
(if (= counter 0)
(PPDF-abort alayout originalPlotter originalMedia originalRotation
originalStyleSheet originalPlotType originalWithStyles
oldBgPlot 1 oldError (PPDF-T "msg_no_frames")))
(setq frameList (PPDF-sort-frames frameList sortMode))
(setq p (PPDF-max-existing outpath prefix suffix))
(setq counter (length frameList))
(princ
(strcat (PPDF-T "pr_start_num")
(PPDF-pad-left (itoa (1+ p)) 3 "0")
(PPDF-T "pr_frames")
(itoa counter)
(PPDF-T "pr_plotter")
plotterCfg
(PPDF-T "pr_paper")
paperCanon
(PPDF-T "pr_plotting")))
(setq i 0)
(foreach frame frameList
(setq pt1 (vlax-make-safearray vlax-vbdouble '(0 . 1)))
(vlax-safearray-put-element pt1 0 (car frame))
(vlax-safearray-put-element pt1 1 (cadr frame))
(setq pt2 (vlax-make-safearray vlax-vbdouble '(0 . 1)))
(vlax-safearray-put-element pt2 0 (caddr frame))
(vlax-safearray-put-element pt2 1 (cadddr frame))
(if (not (PPDF-safe-invoke alayout 'SetWindowToPlot (list pt1 pt2)))
(princ (strcat (PPDF-T "pr_win_fail")
(itoa (1+ i))))
(progn
(setq fname
(strcat outpath
(PPDF-file-prefix prefix suffix) "_"
(PPDF-pad-left (itoa (+ p 1 i)) 3 "0")
".pdf"))
(if (PPDF-safe-invoke-bool aplot 'PlotToFile (list fname))
(progn
(setq printedFiles (cons fname printedFiles))
(grtext -1 (strcat "PPDF: " (itoa (1+ i)) "/" (itoa counter))))
(princ (strcat (PPDF-T "pr_plot_fail") fname)))))
(setq i (1+ i)))
(grtext -1 "")
(setvar "BACKGROUNDPLOT" oldBgPlot)
(setvar "CMDECHO" oldCmdecho)
(PPDF-restore-layout alayout originalPlotter originalMedia
originalRotation originalStyleSheet originalPlotType originalWithStyles)
(setq printedFiles (reverse printedFiles))
(setq lastSession
(list (cons 'files   printedFiles)
(cons 'outpath outpath)
(cons 'prefix  prefix)
(cons 'suffix  suffix)))
(setq doneRes (PPDF-show-done counter outpath))
(cond
((= doneRes 1)
(PPDF-open-folder outpath))
((= doneRes 2)
(if (or (null printedFiles)
(< (length printedFiles) 2))
(alert (PPDF-T "msg_need_2"))
(progn
;; Имя объединённого файла всегда из текущих префикса и суффикса
(setq defaultMergeName
(strcat (PPDF-file-prefix prefix suffix) "_merged.pdf"))
(setq mergeParams
(PPDF-merge-dialog defaultMergeName mergeMode mergeAction))
(if mergeParams
(progn
(setq mergeMode   (cadr mergeParams)
mergeAction (caddr mergeParams))
;; Сохраняем в CFG только режим и действие (имя не сохраняем)
(setq cfg (PPDF-load-cfg))
(setq cfg (PPDF-cfg-set cfg "mergeMode"   mergeMode))
(setq cfg (PPDF-cfg-set cfg "mergeAction" mergeAction))
(PPDF-save-cfg cfg)
(setq mergedResult
(PPDF-do-merge
(PPDF-get-merge-files
mergeMode outpath prefix suffix lastSession)
outpath
(car mergeParams)
mergeAction
prefix suffix))
(if mergedResult
(PPDF-show-merged-done mergedResult)
(princ (strcat "
" (PPDF-T "msg_no_merge")))))
(princ (strcat "
" (PPDF-T "msg_merge_cancel")))))))
(T
(if (and (equal mergeAfter "1")
printedFiles
(> (length printedFiles) 1))
(progn
(setq defaultMergeName
(strcat (PPDF-file-prefix prefix suffix) "_merged.pdf"))
(setq mergeParams
(PPDF-merge-dialog defaultMergeName mergeMode mergeAction))
(if mergeParams
(progn
(setq mergeMode   (cadr mergeParams)
mergeAction (caddr mergeParams))
(setq cfg (PPDF-load-cfg))
(setq cfg (PPDF-cfg-set cfg "mergeMode"   mergeMode))
(setq cfg (PPDF-cfg-set cfg "mergeAction" mergeAction))
(PPDF-save-cfg cfg)
(setq mergedResult
(PPDF-do-merge
(PPDF-get-merge-files
mergeMode outpath prefix suffix lastSession)
outpath
(car mergeParams)
mergeAction
prefix suffix))
(if mergedResult
(PPDF-show-merged-done mergedResult)
(princ (strcat "
" (PPDF-T "msg_no_merge")))))
(princ (strcat "
" (PPDF-T "msg_merge_cancel"))))))))
(setq *error* oldError)
(princ)
)
(princ "
PPDF v19.0 loaded. Command: PPDF")
(princ)