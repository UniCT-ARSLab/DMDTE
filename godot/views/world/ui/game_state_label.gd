extends Label

func set_state_text(state: MatchManager.State):
	match state:
		MatchManager.State.WaitingForPlayers:
			self.text = "Waiting for players..."
		MatchManager.State.Countdown:
			self.text = "Starting game..."
		MatchManager.State.InGame:
			self.text = "In game!"
		MatchManager.State.Resetting:
			self.text = "Resetting..."


func _on_match_manager_state_changed(state: MatchManager.State) -> void:
	self.set_state_text(state)
