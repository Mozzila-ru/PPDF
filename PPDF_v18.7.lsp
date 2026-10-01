;;; ============================================================
;;; PPDF v18.7 - Пакетный экспорт в PDF + Объединение
;;; Команда: PPDF
;;; AutoCAD 2014+
;;; ------------------------------------------------------------
;;; Режимы печати:
;;;   1. Выборочная    - клики по рамкам-блокам
;;;   2. Все блоки     - все экземпляры выбранного блока
;;;   3. Одна рамка    - один блок
;;;   4. ЗамкПолилиния - образец блока + замкнутая LWPOLYLINE
;;; ------------------------------------------------------------
;;; Сортировка: По строкам / По столбцам
;;; Имя листов:   префикс_суффикс_NNN.pdf
;;; Имя слияния:  префикс_суффикс_merged.pdf
;;; ------------------------------------------------------------
;;; Формат бумаги: UI - локализованные имена (GetLocaleMediaName
;;; по каждому каноническому), CFG/API - канонические.
;;; ------------------------------------------------------------
;;; Новое в v18.7:
;;;   - Имя объединённого файла всегда собирается из текущих
;;;     префикса и суффикса: префикс_суффикс_merged.pdf.
;;;   - mergeName больше не хранится в CFG (убрано залипание).
;;;   - Сужены edit_box префикса и суффикса под ширину формы.
;;; ------------------------------------------------------------
;;; pdftk.exe положить в папку поддержки AutoCAD
;;; либо в PATH, либо рядом с PPDF.lsp.
;;; ============================================================

(vl-load-com)

;;; ------------------------------------------------------------
;;; Пути
;;; ------------------------------------------------------------
(defun PPDF-cfgdir ( / d)
  (setq d (strcat (getenv "APPDATA") "\\PPDF"))
  (if (not (vl-file-directory-p d)) (vl-mkdir d))
  d
)

(defun PPDF-cfgpath           () (strcat (PPDF-cfgdir) "\\ppdf_settings.cfg"))
(defun PPDF-dclpath           () (strcat (PPDF-cfgdir) "\\ppdf_dialog.dcl"))
(defun PPDF-helpdclpath       () (strcat (PPDF-cfgdir) "\\ppdf_help.dcl"))
(defun PPDF-hintdclpath       () (strcat (PPDF-cfgdir) "\\ppdf_hint.dcl"))
(defun PPDF-donedclpath       () (strcat (PPDF-cfgdir) "\\ppdf_done.dcl"))
(defun PPDF-mergdclpath       () (strcat (PPDF-cfgdir) "\\ppdf_merge.dcl"))
(defun PPDF-preftdclpath      () (strcat (PPDF-cfgdir) "\\ppdf_preflight.dcl"))
(defun PPDF-mergeddone-dclpath() (strcat (PPDF-cfgdir) "\\ppdf_merged_done.dcl"))

;;; ------------------------------------------------------------
;;; Дефолты (без mergeName)
;;; ------------------------------------------------------------
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
  )
)

;;; ------------------------------------------------------------
;;; CFG
;;; ------------------------------------------------------------
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
  (if f
    (progn
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

;;; ------------------------------------------------------------
;;; ActiveX - безопасные обёртки
;;; ------------------------------------------------------------
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

;;; ------------------------------------------------------------
;;; Списки плоттеров / стилей
;;; ------------------------------------------------------------
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

;;; ------------------------------------------------------------
;;; Форматы бумаги: canon + locale
;;; ------------------------------------------------------------
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

;;; ------------------------------------------------------------
;;; DCL - главный диалог
;;; ------------------------------------------------------------
(defun PPDF-write-dcl ( / f)
  (setq f (open (PPDF-dclpath) "w"))
  (if (not f) nil
    (progn
      (write-line "ppdf_dialog : dialog {" f)
      (write-line "  label = \"PPDF v18.7 - Пакетный экспорт + Объединение\";" f)
      (write-line "  : column {" f)
      (write-line "    : boxed_row { label = \"Режим печати\";" f)
      (write-line "      : radio_button { label = \"Выборочная\"; key = \"mode_sel\"; }" f)
      (write-line "      : radio_button { label = \"Все блоки\"; key = \"mode_all\"; }" f)
      (write-line "      : radio_button { label = \"Одна рамка\"; key = \"mode_one\"; }" f)
      (write-line "      : radio_button { label = \"ЗамкПолилиния\"; key = \"mode_poly\"; }" f)
      (write-line "    }" f)
      (write-line "    : row {" f)
      (write-line "      : edit_box { label = \"Префикс:\"; key = \"prefix\"; edit_width = 32; fixed_width = true; }" f)
      (write-line "      : edit_box { label = \"Суффикс:\"; key = \"suffix\"; edit_width = 32; fixed_width = true; }" f)
      (write-line "    }" f)
      (write-line "    : row {" f)
      (write-line "      : edit_box { label = \"Папка:\"; key = \"outpath\"; edit_width = 60; }" f)
      (write-line "      : button { label = \"Обзор...\"; key = \"click_folder\"; width = 12; height = 2.0; }" f)
      (write-line "    }" f)
      (write-line "    : row {" f)
      (write-line "      : boxed_column { label = \"Стиль печати\";" f)
      (write-line "        : list_box { key = \"style\"; height = 9; width = 38; fixed_width = true; } }" f)
      (write-line "      : boxed_column { label = \"Формат бумаги\";" f)
      (write-line "        : list_box { key = \"paper\"; height = 9; width = 42; fixed_width = true; } }" f)
      (write-line "    }" f)
      (write-line "    : row {" f)
      (write-line "      : boxed_column { label = \"Плоттер\";" f)
      (write-line "        : list_box { key = \"plotter\"; height = 7; width = 42; fixed_width = true; } }" f)
      (write-line "      : boxed_column { label = \"Ориентация\";" f)
      (write-line "        : radio_button { label = \"Портретная\"; key = \"orient_portrait\"; }" f)
      (write-line "        : radio_button { label = \"Альбомная\";  key = \"orient_landscape\"; }" f)
      (write-line "      }" f)
      (write-line "    }" f)
      (write-line "    : row {" f)
      (write-line "      : boxed_row { label = \"Порядок нумерации\";" f)
      (write-line "        : radio_button { label = \"По строкам\";  key = \"sort_rows\"; }" f)
      (write-line "        : radio_button { label = \"По столбцам\"; key = \"sort_cols\"; }" f)
      (write-line "      }" f)
      (write-line "      : edit_box { label = \"Масштаб (100=1:100, 0=Вписать):\"; key = \"scale\"; edit_width = 12; }" f)
      (write-line "    }" f)
      (write-line "    : toggle { label = \"После печати предложить объединение PDF\"; key = \"merge_after\"; }" f)
      (write-line "    spacer;" f)
      (write-line "    : row {" f)
      (write-line "      : button { label = \"?\"; key = \"show_help\"; width = 4; height = 2.2; }" f)
      (write-line "      : button { label = \"Сохранить\"; key = \"save_cfg\"; width = 18; height = 2.2; }" f)
      (write-line "      : button { label = \"Открыть папку\"; key = \"open_folder\"; width = 18; height = 2.2; }" f)
      (write-line "      : button { label = \"Отбор и печать\"; key = \"do_print\"; width = 22; height = 2.2; is_default = true; }" f)
      (write-line "      : button { label = \"Отмена\"; key = \"cancel\"; width = 14; height = 2.2; is_cancel = true; }" f)
      (write-line "    }" f)
      (write-line "  }" f)
      (write-line "}" f)
      (close f) T))
)

;;; ------------------------------------------------------------
;;; DCL - справка
;;; ------------------------------------------------------------
(defun PPDF-write-help-dcl ( / f)
  (setq f (open (PPDF-helpdclpath) "w"))
  (if (not f) nil
    (progn
      (write-line "ppdf_help : dialog { label = \"PPDF v18.7 - Справка\";" f)
      (write-line "  : column {" f)
      (write-line "    : boxed_column { label = \"НАЗНАЧЕНИЕ\";" f)
      (write-line "      : text { label = \"  Пакетная печать блоков-рамок в отдельные PDF\"; }" f)
      (write-line "      : text { label = \"  с последующим объединением в один файл.\"; }" f)
      (write-line "    }" f)
      (write-line "    : boxed_column { label = \"1. РЕЖИМЫ ВЫБОРА РАМОК\";" f)
      (write-line "      : text { label = \"  Выборочная    - клики по блокам (C - отмена последнего)\"; }" f)
      (write-line "      : text { label = \"  Все блоки     - все экземпляры блока, указанного мышью\"; }" f)
      (write-line "      : text { label = \"  Одна рамка    - печать только одного блока\"; }" f)
      (write-line "      : text { label = \"  ЗамкПолилиния - образец блока + замкнутая LWPOLYLINE\"; }" f)
      (write-line "      : text { label = \"                  (берутся блоки внутри контура)\"; }" f)
      (write-line "    }" f)
      (write-line "    : boxed_column { label = \"2. ИМЕНА И СОРТИРОВКА\";" f)
      (write-line "      : text { label = \"  Листы:   префикс_суффикс_NNN.pdf\"; }" f)
      (write-line "      : text { label = \"  Слияние: префикс_суффикс_merged.pdf\"; }" f)
      (write-line "      : text { label = \"  Нумерация листов продолжает последнюю.\"; }" f)
      (write-line "      : text { label = \"  Порядок: По строкам / По столбцам.\"; }" f)
      (write-line "    }" f)
      (write-line "    : boxed_column { label = \"3. МАСШТАБ\";" f)
      (write-line "      : text { label = \"  Пусто или 0  - Вписать (Fit).\"; }" f)
      (write-line "      : text { label = \"  100          - 1:100\"; }" f)
      (write-line "      : text { label = \"  50           - 1:50\"; }" f)
      (write-line "    }" f)
      (write-line "    : boxed_column { label = \"4. ФОРМАТЫ БУМАГИ\";" f)
      (write-line "      : text { label = \"  В списке - локализованные имена AutoCAD.\"; }" f)
      (write-line "      : text { label = \"  В CFG и API - канонические.\"; }" f)
      (write-line "    }" f)
      (write-line "    : boxed_column { label = \"5. ОБЪЕДИНЕНИЕ PDF (pdftk.exe)\";" f)
      (write-line "      : text { label = \"  Имя = префикс_суффикс_merged.pdf\"; }" f)
      (write-line "      : text { label = \"  (всегда из текущих настроек).\"; }" f)
      (write-line "      : text { label = \"  Режимы: Последняя сессия / Текущая папка / Глобально.\"; }" f)
      (write-line "      : text { label = \"  Исходники: Архивировать или Удалить.\"; }" f)
      (write-line "      : text { label = \"  pdftk.exe - в Support, PATH или рядом с LSP.\"; }" f)
      (write-line "    }" f)
      (write-line "    : boxed_column { label = \"6. ПРЕДПОЛЁТНАЯ ПРОВЕРКА\";" f)
      (write-line "      : text { label = \"  Если в папке уже есть PDF - выбор:\"; }" f)
      (write-line "      : text { label = \"  Продолжить / Очистить / Архивировать / Отмена.\"; }" f)
      (write-line "    }" f)
      (write-line "    : boxed_column { label = \"7. АРХИВ ПРИ СЛИЯНИИ\";" f)
      (write-line "      : text { label = \"  Папка: ГодМесяцДень_ЧасыМинуты_merged\"; }" f)
      (write-line "      : text { label = \"  внутри целевой. Если занята - _01, _02, ...\"; }" f)
      (write-line "    }" f)
      (write-line "    : boxed_column { label = \"8. ТИХАЯ ПЕЧАТЬ\";" f)
      (write-line "      : text { label = \"  Настраивается в плоттере DWG To PDF.pc3.\"; }" f)
      (write-line "      : text { label = \"  Пошаговая инструкция - по кнопке ниже.\"; }" f)
      (write-line "    }" f)
      (write-line "    : boxed_column { label = \"9. ПАМЯТЬ НАСТРОЕК\";" f)
      (write-line "      : text { label = \"  Все настройки и режим слияния сохраняются.\"; }" f)
      (write-line "      : text { label = \"  Имя merged-файла НЕ запоминается -\"; }" f)
      (write-line "      : text { label = \"  всегда из текущих префикса и суффикса.\"; }" f)
      (write-line "    }" f)
      (write-line "    spacer;" f)
      (write-line "    : row {" f)
      (write-line "      : button { label = \"Тихая печать\"; key = \"silent\"; width = 20; height = 2.0; }" f)
      (write-line "      : button { label = \"Закрыть\"; key = \"close_help\"; width = 16; height = 2.0; is_default = true; is_cancel = true; }" f)
      (write-line "    }" f)
      (write-line "  }" f)
      (write-line "}" f)
      (close f) T))
)

;;; ------------------------------------------------------------
;;; DCL - инструкция по тихой печати
;;; ------------------------------------------------------------
(defun PPDF-write-hint-dcl ( / f)
  (setq f (open (PPDF-hintdclpath) "w"))
  (if (not f) nil
    (progn
      (write-line "ppdf_hint : dialog { label = \"PPDF - Тихая печать (без открытия PDF)\";" f)
      (write-line "  : column {" f)
      (write-line "    : boxed_column { label = \"ПОЧЕМУ ОТКРЫВАЕТСЯ PDF\";" f)
      (write-line "      : text { label = \"  Драйвер DWG To PDF по умолчанию показывает\"; }" f)
      (write-line "      : text { label = \"  результат печати после каждой публикации.\"; }" f)
      (write-line "      : text { label = \"  Опция хранится внутри PC3-файла плоттера.\"; }" f)
      (write-line "    }" f)
      (write-line "    : boxed_column { label = \"ШАГИ НАСТРОЙКИ\";" f)
      (write-line "      : text { label = \"  1. Ctrl+P - открыть окно \\\"Печать\\\".\"; }" f)
      (write-line "      : text { label = \"  2. В списке плоттеров выбрать DWG To PDF.pc3.\"; }" f)
      (write-line "      : text { label = \"  3. Нажать \\\"Свойства\\\" рядом со списком.\"; }" f)
      (write-line "      : text { label = \"  4. В дереве выбрать \\\"Настройка плоттера\\\" -\"; }" f)
      (write-line "      : text { label = \"     \\\"Дополнительные свойства\\\" -\"; }" f)
      (write-line "      : text { label = \"     \\\"Параметры PDF\\\" (Custom Properties).\"; }" f)
      (write-line "      : text { label = \"  5. Снять галочку \\\"Показывать результаты\\\"\"; }" f)
      (write-line "      : text { label = \"     (\\\"Show results in viewer\\\").\"; }" f)
      (write-line "      : text { label = \"  6. OK. На вопрос \\\"Сохранить изменения\\\" -\"; }" f)
      (write-line "      : text { label = \"     \\\"Сохранить в следующем файле\\\"\"; }" f)
      (write-line "      : text { label = \"     (Save changes to the following file).\"; }" f)
      (write-line "      : text { label = \"  7. Дописать к имени PC3 любое англ. слово,\"; }" f)
      (write-line "      : text { label = \"     напр. \\\"DWG To PDF_Silent.pc3\\\".\"; }" f)
      (write-line "      : text { label = \"  8. Закрыть окно печати.\"; }" f)
      (write-line "    }" f)
      (write-line "    : boxed_column { label = \"В PPDF\";" f)
      (write-line "      : text { label = \"  В списке плоттеров выбрать новый\"; }" f)
      (write-line "      : text { label = \"  \\\"DWG To PDF_Silent.pc3\\\" и сохранить настройки.\"; }" f)
      (write-line "      : text { label = \"  После этого PDF не будет открываться.\"; }" f)
      (write-line "    }" f)
      (write-line "    : boxed_column { label = \"ПРИМЕЧАНИЕ\";" f)
      (write-line "      : text { label = \"  Изменение \\\"на лету\\\" через LISP невозможно -\"; }" f)
      (write-line "      : text { label = \"  AutoCAD хранит эту опцию внутри PC3-файла.\"; }" f)
      (write-line "    }" f)
      (write-line "    spacer;" f)
      (write-line "    : button { label = \"Понятно\"; key = \"close_hint\"; is_default = true; is_cancel = true; }" f)
      (write-line "  }" f)
      (write-line "}" f)
      (close f) T))
)

;;; ------------------------------------------------------------
;;; DCL - готово
;;; ------------------------------------------------------------
(defun PPDF-write-done-dcl ( / f)
  (setq f (open (PPDF-donedclpath) "w"))
  (if (not f) nil
    (progn
      (write-line "ppdf_done : dialog { label = \"PPDF - Готово\";" f)
      (write-line "  : column {" f)
      (write-line "    : text { key = \"done_msg\"; }" f)
      (write-line "    : text { key = \"done_path\"; }" f)
      (write-line "    spacer;" f)
      (write-line "    : row {" f)
      (write-line "      : button { label = \"Открыть папку\"; key = \"open\"; width = 18; }" f)
      (write-line "      : button { label = \"Объединить\";   key = \"merge\"; width = 18; }" f)
      (write-line "      : button { label = \"OK\"; key = \"ok\"; width = 12; is_default = true; is_cancel = true; }" f)
      (write-line "    }" f)
      (write-line "  }" f)
      (write-line "}" f)
      (close f) T))
)

;;; ------------------------------------------------------------
;;; DCL - окно объединения
;;; ------------------------------------------------------------
(defun PPDF-write-merge-dcl ( / f)
  (setq f (open (PPDF-mergdclpath) "w"))
  (if (not f) nil
    (progn
      (write-line "ppdf_merge : dialog { label = \"PPDF - Объединение PDF\";" f)
      (write-line "  : column {" f)
      (write-line "    : boxed_row { label = \"Режим\";" f)
      (write-line "      : radio_button { label = \"Последняя сессия\"; key = \"mode_session\"; }" f)
      (write-line "      : radio_button { label = \"Текущая папка\";   key = \"mode_folder\"; }" f)
      (write-line "      : radio_button { label = \"Глобально\";       key = \"mode_global\"; }" f)
      (write-line "    }" f)
      (write-line "    : edit_box { label = \"Имя файла:\"; key = \"merged_name\"; edit_width = 60; }" f)
      (write-line "    : boxed_row { label = \"Исходные файлы после слияния\";" f)
      (write-line "      : radio_button { label = \"Архивировать в _merged\"; key = \"act_archive\"; }" f)
      (write-line "      : radio_button { label = \"Удалить\";                key = \"act_delete\";  }" f)
      (write-line "    }" f)
      (write-line "    spacer;" f)
      (write-line "    : row {" f)
      (write-line "      : button { label = \"Объединить\"; key = \"do_merge\"; width = 22; is_default = true; }" f)
      (write-line "      : button { label = \"Отмена\";     key = \"cancel\";   width = 14; is_cancel = true; }" f)
      (write-line "    }" f)
      (write-line "  }" f)
      (write-line "}" f)
      (close f) T))
)

;;; ------------------------------------------------------------
;;; DCL - предполётная проверка
;;; ------------------------------------------------------------
(defun PPDF-write-preft-dcl ( / f)
  (setq f (open (PPDF-preftdclpath) "w"))
  (if (not f) nil
    (progn
      (write-line "ppdf_preflight : dialog { label = \"PPDF - Внимание\";" f)
      (write-line "  : column {" f)
      (write-line "    : text { key = \"msg\"; width = 60; }" f)
      (write-line "    spacer;" f)
      (write-line "    : row {" f)
      (write-line "      : button { label = \"Продолжить\";    key = \"cont\";   width = 18; is_default = true; }" f)
      (write-line "      : button { label = \"Очистить\";      key = \"clean\";  width = 18; }" f)
      (write-line "      : button { label = \"Архивировать\";  key = \"arch\";   width = 18; }" f)
      (write-line "      : button { label = \"Отмена\";        key = \"cancel\"; width = 14; is_cancel = true; }" f)
      (write-line "    }" f)
      (write-line "  }" f)
      (write-line "}" f)
      (close f) T))
)

;;; ------------------------------------------------------------
;;; DCL - финал после слияния
;;; ------------------------------------------------------------
(defun PPDF-write-merged-done-dcl ( / f)
  (setq f (open (PPDF-mergeddone-dclpath) "w"))
  (if (not f) nil
    (progn
      (write-line "ppdf_merged_done : dialog { label = \"PPDF - Объединение завершено\";" f)
      (write-line "  : column {" f)
      (write-line "    : text { key = \"msg\"; }" f)
      (write-line "    : text { key = \"path\"; width = 70; }" f)
      (write-line "    spacer;" f)
      (write-line "    : row {" f)
      (write-line "      : button { label = \"Открыть папку\"; key = \"open_folder\"; width = 18; }" f)
      (write-line "      : button { label = \"Открыть файл\"; key = \"open_file\";   width = 18; }" f)
      (write-line "      : button { label = \"OK\";           key = \"ok\"; width = 12; is_default = true; is_cancel = true; }" f)
      (write-line "    }" f)
      (write-line "  }" f)
      (write-line "}" f)
      (close f) T))
)

;;; ------------------------------------------------------------
;;; Показ диалогов
;;; ------------------------------------------------------------
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
            (alert "Не удалось открыть окно инструкции."))
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
                (strcat "Экспортировано: " (itoa counter) " листов."))
              (set_tile "done_path" (strcat "Папка: " outpath))

              ;; При одном файле кнопка "Объединить" неактивна
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
              (set_tile "msg"  "PDF успешно объединён.")
              (set_tile "path" (strcat "Файл: " mergedFile))
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

;;; ------------------------------------------------------------
;;; Перемещение файла
;;; ------------------------------------------------------------
(defun PPDF-move-file (src dst / )
  (if (or (null src) (null dst)) nil
    (if (vl-file-rename src dst)
      T
      (if (vl-file-copy src dst)
        (progn (vl-file-delete src) T)
        nil)))
)

;;; ------------------------------------------------------------
;;; Метка времени ГодМесяцДень_ЧасыМинуты (20251001_1435)
;;; ------------------------------------------------------------
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

;;; ------------------------------------------------------------
;;; Уникальное имя папки: baseName, baseName_01, baseName_02 ... _99
;;; ------------------------------------------------------------
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
;;; Предполётная проверка
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
                  (strcat "В целевой папке найдено " (itoa count)
                          " PDF-файлов.\nОни могут попасть в объединённый документ."))
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
               (princ (strcat "\n[PPDF] Очищено " (itoa count) " файлов."))
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
                   (princ (strcat "\n[!] Не удалось переместить: " f))))
               (princ (strcat "\n[PPDF] Архивировано в " archiveDir))
               T)
              (T T)))))))
)

;;; ------------------------------------------------------------
;;; Утилиты
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

(defun PPDF-pad-left (s n ch / res)
  (setq res s)
  (while (< (strlen res) n) (setq res (strcat ch res)))
  res
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
               "Выберите папку для сохранения PDF" 0
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
        (alert (strcat "Папка не существует:\n" p))))
    (alert "Папка не задана."))
  (princ)
)

;;; Открыть файл в ассоциированной программе
;;; (Acrobat, Edge, ...). Проверка через vl-file-systime - работает
;;; с абсолютными путями, в отличие от findfile.
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
          (alert (strcat "Файл не найден:\n" path))
          nil)))
    (progn
      (alert "Путь к файлу не задан.")
      nil))
)

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

(defun PPDF-select-blocks ( / sel ent entdata picked counter continue)
  (setq picked nil counter 0 continue T)
  (princ "\n=== Выборочная печать блоков ===")
  (princ "\nКлик по блоку-рамке - отметить/снять. C - отменить последний. Enter - продолжить.")
  (while continue
    (initget "C")
    (setq sel
      (entsel (strcat "\n[Отмечено: " (itoa counter)
                      "] Укажите рамку [C - отмена]: ")))
    (cond
      ((null sel) (setq continue nil) (PPDF-highlight nil))
      ((= (type sel) 'STR)
       (if (= sel "C")
         (if picked
           (progn
             (setq picked (vl-remove (last picked) picked))
             (setq counter (length picked))
             (PPDF-highlight picked)
             (princ (strcat "\n[-] Отменён последний. Осталось: " (itoa counter))))
           (princ "\n[!] Нечего отменять."))))
      (T
       (setq ent (car sel) entdata (entget ent))
       (cond
         ((not (= (cdr (assoc 0 entdata)) "INSERT"))
          (princ "\n[!] Это не блок."))
         ((member ent picked)
          (setq picked (vl-remove ent picked)
                counter (length picked))
          (PPDF-highlight picked)
          (princ (strcat "\n[-] Снята. Осталось: " (itoa counter))))
         (T
          (setq picked (append picked (list ent))
                counter (length picked))
          (PPDF-highlight picked)
          (princ (strcat "\n[+] Отмечена №" (itoa counter))))))))
  picked
)

;;; ------------------------------------------------------------
;;; Восстановление Layout
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
      (alert (strcat
        "pdftk.exe не найден!\n\n"
        "Положите pdftk.exe в папку поддержки AutoCAD\n"
        "(C:\\Program Files\\Autodesk\\AutoCAD 20XX\\Support\\)\n"
        "или в любую папку из Support File Search Path.\n"
        "Печать будет работать, объединение — нет."))
      nil))
)

(defun PPDF-run-sync (cmd / wsh wrapped raw rc)
  (setq wrapped (strcat "cmd.exe /c \"" cmd "\""))
  (setq wsh (vl-catch-all-apply
              '(lambda () (vlax-create-object "WScript.Shell")) '()))
  (if (vl-catch-all-error-p wsh)
    (progn
      (princ (strcat "\n[PPDF] WScript.Shell недоступен: "
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
         (princ (strcat "\n[PPDF] Run error: "
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
            (setq acc (strcat acc line "\n")))
          (close f)))))
  acc
)

(defun PPDF-do-merge
       (fileList outPath mergedName action prefix suffix
        / pdftk cmd tmpFile errFile outFile rc ok errTxt total i
          mergedDir src dst base ts)
  (if (or (null fileList) (< (length fileList) 1))
    (progn (alert "Нет файлов для объединения.") nil)
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

        (princ (strcat "\n[PPDF] Объединение " (itoa total) " файлов..."))
        (grtext -1 (strcat "PPDF: объединение " (itoa total) " файлов..."))
        (setq rc (PPDF-run-sync cmd))
        (grtext -1 "")

        (setq ok (vl-file-systime tmpFile))

        (if ok
          (progn
            (cond
              ((= action "DELETE")
               (foreach fl fileList
                 (if (not (vl-file-delete fl))
                   (princ (strcat "\n[!] Не удалось удалить: " fl))))
               (princ (strcat "\n[PPDF] Удалено " (itoa total) " файлов.")))
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
                   (princ (strcat "\n[!] Не удалось переместить: " fl))))
               (princ (strcat "\n[PPDF] Архивировано в " mergedDir))))
            (if (vl-file-systime errFile) (vl-file-delete errFile))
            (if (vl-file-systime outFile) (vl-file-delete outFile))
            tmpFile)
          (progn
            (setq errTxt (PPDF-read-file errFile))
            (if (vl-file-systime errFile) (vl-file-delete errFile))
            (if (vl-file-systime outFile) (vl-file-delete outFile))
            (alert
              (strcat
                "pdftk не создал файл результата.\n\n"
                "Код возврата: " (itoa rc) "\n\n"
                "stderr:\n"
                (if (= errTxt "") "(пусто)" errTxt)
                "\nПроверьте:\n"
                "  - пути к файлам и папке не содержат лишних символов\n"
                "  - исходные PDF не повреждены и не зашифрованы\n"
                "  - в папке достаточно прав на запись"))
            nil))))))

;;; ------------------------------------------------------------
;;; Сбор файлов для объединения
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

;;; ------------------------------------------------------------
;;; Обработчики главного диалога
;;; ------------------------------------------------------------
(defun PPDF-DLG-plotter-change ( / idx plt ml canon locale newCanon newIdx i)
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
            (set_tile "paper" (itoa newIdx))))))))

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
  (setq PPDF-DLG-plotterCfg(nth (atoi (get_tile "plotter"))
                                PPDF-DLG-plotterList))
  (setq PPDF-DLG-orientCfg (if (= (get_tile "orient_landscape") "1")
                               "Landscape" "Portrait"))
  (setq PPDF-DLG-plotMode  (cond
                             ((= (get_tile "mode_all")  "1") "A")
                             ((= (get_tile "mode_one")  "1") "1")
                             ((= (get_tile "mode_poly") "1") "P")
                             (T "S")))
  (setq PPDF-DLG-sortMode  (if (= (get_tile "sort_cols") "1") "C" "R"))
  (setq PPDF-DLG-mergeAfter(if (= (get_tile "merge_after") "1") "1" "0"))
)

;;; В CFG сохраняются ТОЛЬКО 11 ключей главного окна.
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
    (cons "mergeAfter" PPDF-DLG-mergeAfter))
)

(defun PPDF-DLG-save-cfg ( / cfg newCfg)
  (PPDF-DLG-read-tiles)
  (setq cfg (PPDF-load-cfg))
  (setq newCfg (PPDF-DLG-build-cfg))
  (foreach kv newCfg
    (setq cfg (PPDF-cfg-set cfg (car kv) (cdr kv))))
  (if (PPDF-save-cfg cfg)
    (alert "Настройки сохранены.")
    (alert "Не удалось сохранить настройки."))
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

;;; ------------------------------------------------------------
;;; Хелпер аварийного выхода
;;; ------------------------------------------------------------
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

;;; ------------------------------------------------------------
;;; Главная команда
;;; ------------------------------------------------------------
(defun c:PPDF ( /
                 cfg adoc acad alayout aplot
                 styleList plotterList filteredPlotterList
                 mediaLists canonList localeList
                 prefix suffix outpath
                 styleName paperCanon paperIdx
                 plotterCfg
                 orientCfg scaleStr plotMode sortMode mergeAfter
                 mergeMode mergeAction
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
      (princ (strcat "\nPPDF: ошибка - " msg))
      (princ "\nPPDF: прервано."))
    (setq *error* oldError)
    (princ)
  )

  (setq oldBgPlot  (getvar "BACKGROUNDPLOT"))
  (setq oldCmdecho (getvar "CMDECHO"))

  (setq acad (vl-catch-all-apply
               '(lambda () (vlax-get-acad-object)) '()))
  (if (vl-catch-all-error-p acad)
    (PPDF-abort nil nil nil nil nil nil nil oldBgPlot oldCmdecho oldError
                "Не удалось подключиться к AutoCAD."))

  (setq adoc (vl-catch-all-apply
               '(lambda () (vla-get-ActiveDocument acad)) '()))
  (if (vl-catch-all-error-p adoc)
    (PPDF-abort nil nil nil nil nil nil nil oldBgPlot oldCmdecho oldError
                "Не удалось получить документ."))

  (setq alayout (vl-catch-all-apply
                  '(lambda () (vla-get-ActiveLayout adoc)) '()))
  (if (vl-catch-all-error-p alayout)
    (PPDF-abort nil nil nil nil nil nil nil oldBgPlot oldCmdecho oldError
                "Не удалось получить Layout."))

  (setq aplot (vl-catch-all-apply
                '(lambda () (vla-get-Plot adoc)) '()))
  (if (vl-catch-all-error-p aplot)
    (PPDF-abort alayout nil nil nil nil nil nil oldBgPlot oldCmdecho oldError
                "Не удалось получить объект Plot."))

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
  (if (or (null mergeMode)   (= mergeMode ""))   (setq mergeMode   "SESSION"))
  (if (or (null mergeAction) (= mergeAction "")) (setq mergeAction "ARCHIVE"))

  (setq styleList   (PPDF-get-style-list alayout))
  (setq plotterList (PPDF-get-plotter-list alayout))
  (if (null plotterList)
    (PPDF-abort alayout originalPlotter originalMedia originalRotation
      originalStyleSheet originalPlotType originalWithStyles
      oldBgPlot oldCmdecho oldError
      "AutoCAD не вернул список плоттеров."))

  (setq filteredPlotterList (PPDF-only-pdf-plotters plotterList))
  (if filteredPlotterList
    (setq plotterList filteredPlotterList)
    (princ "\n[PPDF] DWG To PDF* не найдены, показываю все."))

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
      "Не удалось получить список форматов бумаги."))

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
      "Не удалось создать DCL."))

  (setq dResult 2)

  (while (>= dResult 2)
    (setq dcl_id (load_dialog (PPDF-dclpath)))
    (if (< dcl_id 0)
      (PPDF-abort alayout originalPlotter originalMedia originalRotation
        originalStyleSheet originalPlotType originalWithStyles
        oldBgPlot oldCmdecho oldError
        "Не удалось загрузить DCL."))

    (if (not (new_dialog "ppdf_dialog" dcl_id))
      (progn
        (unload_dialog dcl_id)
        (PPDF-abort alayout originalPlotter originalMedia originalRotation
          originalStyleSheet originalPlotType originalWithStyles
          oldBgPlot oldCmdecho oldError
          "Не удалось открыть окно PPDF.")))

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
      ((= dResult 6) (PPDF-show-help) (setq dResult 2))))

  (if (or (= dResult 0) (= dResult -1))
    (progn
      (PPDF-restore-layout alayout originalPlotter originalMedia
        originalRotation originalStyleSheet originalPlotType originalWithStyles)
      (if oldBgPlot  (setvar "BACKGROUNDPLOT" oldBgPlot))
      (if oldCmdecho (setvar "CMDECHO" oldCmdecho))
      (setq *error* oldError)
      (princ "\nPPDF: отменено.") (princ) (exit)))

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
      (princ "\nPPDF: отменено пользователем.") (princ) (exit)))

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
      (strcat "Не удалось установить плоттер:\n" plotterCfg)))

  (PPDF-refresh-layout alayout)

  (setq mediaLists (PPDF-get-media-lists alayout))
  (setq canonList  (car mediaLists))
  (setq localeList (cadr mediaLists))
  (if (or (null canonList) (= (length canonList) 0))
    (PPDF-abort alayout originalPlotter originalMedia originalRotation
      originalStyleSheet originalPlotType originalWithStyles
      oldBgPlot 1 oldError
      (strcat "Плоттер не вернул форматы бумаги:\n" plotterCfg)))

  (setq paperIdx (vl-position paperCanon canonList))
  (if (null paperIdx)
    (progn
      (setq paperSize (PPDF-agree-media paperCanon canonList))
      (setq paperIdx (cond ((setq p (vl-position paperSize canonList)) p) (T 0)))
      (setq paperCanon paperSize)))
  (setq paperSize (nth paperIdx canonList))

  (if (/= paperSize paperCanon)
    (princ (strcat "\n[PPDF] Формат '" paperCanon
                   "' недоступен, использую '" paperSize "'.")))
  (setq paperCanon paperSize)

  (if (not (PPDF-safe-put-property alayout 'CanonicalMediaName paperCanon))
    (PPDF-abort alayout originalPlotter originalMedia originalRotation
      originalStyleSheet originalPlotType originalWithStyles
      oldBgPlot 1 oldError
      (strcat "Не удалось установить формат: " paperCanon)))

  (if (= orientCfg "Landscape")
    (PPDF-safe-put-property alayout 'PlotRotation 0)
    (PPDF-safe-put-property alayout 'PlotRotation 1))

  (PPDF-safe-put-property alayout 'CenterPlot         :vlax-true)
  (PPDF-safe-put-property alayout 'PlotWithLineweights :vlax-true)

  (if (/= styleSheet "")
    (progn
      (PPDF-safe-put-property alayout 'PlotWithPlotStyles :vlax-true)
      (if (not (PPDF-safe-put-property alayout 'StyleSheet styleSheet))
        (princ (strcat "\n[!] Не удалось установить стиль: " styleSheet))))
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
         oldBgPlot 1 oldError "Рамки не выбраны."))
     (foreach e pickedList
       (setq p (PPDF-bbox e))
       (if p (setq frameList (append frameList (list p)))))
     (setq counter (length frameList)))

    ((= plotMode "1")
     (princ "\n=== Одна рамка ===")
     (princ "\nУкажите рамку-блок для печати: ")
     (setq sel (entsel ""))
     (if (null sel)
       (PPDF-abort alayout originalPlotter originalMedia originalRotation
         originalStyleSheet originalPlotType originalWithStyles
         oldBgPlot 1 oldError "Выбор отменён."))
     (setq ent (car sel))
     (if (/= (cdr (assoc 0 (entget ent))) "INSERT")
       (PPDF-abort alayout originalPlotter originalMedia originalRotation
         originalStyleSheet originalPlotType originalWithStyles
         oldBgPlot 1 oldError "Не блок."))
     (setq p (PPDF-bbox ent))
     (if p (setq frameList (list p)))
     (setq counter (length frameList)))

    ((= plotMode "A")
     (princ "\n=== Все блоки выбранного типа ===")
     (princ "\nУкажите любую рамку для определения типа блока: ")
     (setq sel (entsel ""))
     (if (null sel)
       (PPDF-abort alayout originalPlotter originalMedia originalRotation
         originalStyleSheet originalPlotType originalWithStyles
         oldBgPlot 1 oldError "Отменено."))
     (setq ent (car sel))
     (if (/= (cdr (assoc 0 (entget ent))) "INSERT")
       (PPDF-abort alayout originalPlotter originalMedia originalRotation
         originalStyleSheet originalPlotType originalWithStyles
         oldBgPlot 1 oldError "Не блок."))
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
         oldBgPlot 1 oldError "Блоки не найдены."))
     (setq counter (length frameList)))

    ((= plotMode "P")
     (princ "\n=== ЗамкПолилиния ===")
     (princ "\nУкажите образец рамки-блока: ")
     (setq sel (entsel ""))
     (if (null sel)
       (PPDF-abort alayout originalPlotter originalMedia originalRotation
         originalStyleSheet originalPlotType originalWithStyles
         oldBgPlot 1 oldError "Образец не указан."))
     (setq sampleEnt (car sel))
     (if (/= (cdr (assoc 0 (entget sampleEnt))) "INSERT")
       (PPDF-abort alayout originalPlotter originalMedia originalRotation
         originalStyleSheet originalPlotType originalWithStyles
         oldBgPlot 1 oldError "Не блок."))

     (princ "\nУкажите замкнутую полилинию-контейнер: ")
     (setq sel (entsel ""))
     (if (null sel)
       (PPDF-abort alayout originalPlotter originalMedia originalRotation
         originalStyleSheet originalPlotType originalWithStyles
         oldBgPlot 1 oldError "Полилиния не указана."))
     (setq polyEnt (car sel))
     (if (not (PPDF-closed-lwpoly-p polyEnt))
       (PPDF-abort alayout originalPlotter originalMedia originalRotation
         originalStyleSheet originalPlotType originalWithStyles
         oldBgPlot 1 oldError
         "Граница должна быть ЗАМКНУТОЙ LWPOLYLINE."))

     (setq frameList (PPDF-collect-inside-poly sampleEnt polyEnt))
     (if (or (null frameList) (= (length frameList) 0))
       (PPDF-abort alayout originalPlotter originalMedia originalRotation
         originalStyleSheet originalPlotType originalWithStyles
         oldBgPlot 1 oldError
         "Внутри полилинии ничего не найдено."))
     (setq counter (length frameList))))

  (if (= counter 0)
    (PPDF-abort alayout originalPlotter originalMedia originalRotation
      originalStyleSheet originalPlotType originalWithStyles
      oldBgPlot 1 oldError "Нет рамок."))

  (setq frameList (PPDF-sort-frames frameList sortMode))

  (setq p (PPDF-max-existing outpath prefix suffix))
  (setq counter (length frameList))

  (princ
    (strcat "\nНачало нумерации: " (PPDF-pad-left (itoa (1+ p)) 3 "0")
            "\nРамок: " (itoa counter)
            "\nПлоттер: " plotterCfg
            "\nФормат: " paperCanon
            "\nПечать..."))

  (setq i 0)
  (foreach frame frameList
    (setq pt1 (vlax-make-safearray vlax-vbdouble '(0 . 1)))
    (vlax-safearray-put-element pt1 0 (car frame))
    (vlax-safearray-put-element pt1 1 (cadr frame))

    (setq pt2 (vlax-make-safearray vlax-vbdouble '(0 . 1)))
    (vlax-safearray-put-element pt2 0 (caddr frame))
    (vlax-safearray-put-element pt2 1 (cadddr frame))

    (if (not (PPDF-safe-invoke alayout 'SetWindowToPlot (list pt1 pt2)))
      (princ (strcat "\n[!] Не удалось установить окно для рамки "
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
          (princ (strcat "\n[!] Ошибка печати: " fname)))))
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
       (alert "Для объединения нужно минимум два файла.")
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
               (princ "\nPPDF: объединение не выполнено.")))
           (princ "\nPPDF: объединение отменено.")))))

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
               (princ "\nPPDF: объединение не выполнено.")))
           (princ "\nPPDF: объединение отменено."))))))

  (setq *error* oldError)
  (princ)
)

(princ "\nPPDF v18.7 загружен. Команда: PPDF")
(princ)