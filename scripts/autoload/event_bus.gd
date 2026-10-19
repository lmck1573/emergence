extends Node
## Cross-scene system notifications. This bus stores no state.

## Persistent state changed; reevaluate configured events.
signal state_changed()
## A scene-authored investigation step completed.
signal object_step_completed(object_id: String, step_id: String)
## A player clicked an investigation object.
signal object_clicked(object_id: String)
## Every step of an object completed for the first time.
signal object_investigated(object_id: String)
## Request the reusable full-screen reader.
signal fulltext_requested(text_id: String, next_label: String, can_previous: bool)
## Reader closed after its final page.
signal fulltext_finished(text_id: String)
## Reader requested another investigation step.
signal investigation_next()
## Reader requested an earlier investigation step.
signal investigation_previous()
## Request a dialogue by its canonical ID.
signal dialogue_requested(dialogue_id: String)
## A dialogue completed normally.
signal dialogue_finished(dialogue_id: String)
## A toolbar topic was selected.
signal topic_requested(topic_id: String)
## A toolbar content item was selected.
signal feed_requested(content_id: String)
## Request feeding every currently available content item.
signal feed_all_requested()
## A topic completed normally.
signal topic_completed(topic_id: String)
## A truth selection must be presented.
signal choice_requested(event_id: String, choice: Dictionary)
## The player made a valid choice.
signal choice_made(event_id: String, option: String)
## A configured event completed.
signal event_completed(event_id: String)
## An area was unlocked.
signal region_unlocked(region_id: String)
## A small nonmodal notification was requested.
signal toast_requested(text: String)
## All scene controls must respect modal presentation.
signal modal_changed(blocked: bool)
## A presentation command was requested.
signal command_requested(command_id: String)
## A presentation command finished.
signal command_finished(command_id: String)
## A first-stage ending transition was requested.
signal ending_requested()
## Ending transition reached black.
signal ending_finished()
## An opening document was selected.
signal opening_requested(key: String, text_id: String)
## A one-shot audio cue was requested.
signal audio_cue_requested(cue_id: String)
## Stop a currently playing one-shot sound cue.
signal audio_cue_stop_requested(cue_id: String)
## A dialogue character sound was requested.
signal character_sound_requested(speaker: String)
## A phase-specific background track was requested.
signal phase_bgm_requested(phase: int)
## The global audio mute state was changed.
signal audio_mute_requested(muted: bool)
## The global audio mute state changed.
signal audio_mute_changed(muted: bool)
## A new game session began.
signal game_started()
## Request a scene-independent narrative transition sequence.
signal transition_requested(transition_id: String)
## A narrative transition presentation has finished.
signal transition_finished(transition_id: String)
## Request a date-password puzzle interface.
signal puzzle_requested(puzzle_id: String)
## Request the diary event-list viewer.
signal diary_viewer_requested()
## A puzzle was submitted with its result.
signal puzzle_submitted(puzzle_id: String, answer: String)
