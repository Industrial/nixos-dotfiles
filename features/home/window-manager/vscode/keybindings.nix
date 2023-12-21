[
  {
    key = "ctrl+tab";
    command = "-workbench.action.quickOpenPreviousRecentlyUsedEditorInGroup";
  }
  {
    key = "ctrl+tab";
    command = "workbench.action.nextEditor";
  }
  {
    key = "ctrl+pagedown";
    command = "-workbench.action.nextEditor";
  }
  {
    key = "ctrl+shift+tab";
    command = "workbench.action.previousEditor";
  }
  {
    key = "ctrl+pageup";
    command = "-workbench.action.previousEditor";
  }
  {
    key = "ctrl+shift+tab";
    command = "-workbench.action.quickOpenLeastRecentlyUsedEditorInGroup";
  }
  {
    key = "ctrl+shift+k";
    command = "editor.action.showHover";
    when = "editorTextFocus";
  }
  {
    key = "ctrl+h";
    command = "workbench.action.navigateLeft";
  }
  {
    key = "ctrl+l";
    command = "workbench.action.navigateRight";
  }
  {
    key = "ctrl+k";
    command = "workbench.action.navigateUp";
  }
  {
    key = "ctrl+j";
    command = "workbench.action.navigateDown";
  }
  {
    # "ctrl+j": Selects the next suggestion in the suggestions widget when
    # the widget is visible.
    key = "ctrl+j";
    command = "selectNextSuggestion";
    when = "suggestWidgetVisible";
  }
  {
    # "ctrl+k": Selects the previous suggestion in the suggestions widget
    # when the widget is visible.
    key = "ctrl+k";
    command = "selectPrevSuggestion";
    when = "suggestWidgetVisible";
  }
  {
    # "ctrl+j": Selects the next item in the Quick Open dialog when it is
    # open.
    key = "ctrl+j";
    command = "workbench.action.quickOpenSelectNext";
    when = "inQuickOpen";
  }
  {
    # "ctrl+k": Selects the previous item in the Quick Open dialog when it
    # is open.
    key = "ctrl+k";
    command = "workbench.action.quickOpenSelectPrevious";
    when = "inQuickOpen";
  }

  # Put these here explicitly so they work on OSX (instead of CMD).
  {
    key = "ctrl+p";
    command = "workbench.action.quickOpen";
  }
  {
    key = "ctrl+shift+p";
    command = "workbench.action.showCommands";
  }

  # AI Autocompletion
  {
    key = "alt+enter";
    command = "editor.action.inlineSuggest.trigger";
    when = "editorTextFocus && !editorHasSelection && !inlineSuggestionsVisible";
  }
  {
    key = "ctrl+enter";
    command = "editor.action.inlineSuggest.trigger";
    when = "editorTextFocus && !editorHasSelection && !inlineSuggestionsVisible";
  }
  {
    key = "ctrl+]";
    command = "editor.action.inlineSuggest.showNext";
    when = "editorTextFocus && !editorHasSelection && !inlineSuggestionsVisible";
  }
  {
    key = "ctrl+[";
    command = "editor.action.inlineSuggest.showPrevious";
    when = "editorTextFocus && !editorHasSelection && !inlineSuggestionsVisible";
  }
  # Copilot
  {
    key = "ctrl+shift+enter";
    command = "github.copilot.generate";
    when = "editorTextFocus && github.copilot.activated && !inInteractiveInput && !inInteractiveEditorFocused";
  }
  {
    key = "ctrl+/";
    command = "github.copilot.acceptCursorPanelSolution";
    when = "github.copilot.activated && github.copilot.panelVisible";
  }
  {
    key = "alt+[";
    command = "github.copilot.previousPanelSolution";
    when = "github.copilot.activated && github.copilot.panelVisible";
  }
  {
    key = "alt+]";
    command = "github.copilot.nextPanelSolution";
    when = "github.copilot.activated && github.copilot.panelVisible";
  }
]
