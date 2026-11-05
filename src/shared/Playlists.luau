-- The background music. Every track is from APM Music, which Roblox licenses for use in any experience.
-- The lobby playlist plays between races and the race playlist while you race; each is shuffled and moves
-- on to the next track when one ends. Add, remove or swap tracks here: Id is the Creator Store audio id,
-- and Name is shown in the corner when the track starts and in Settings.

export type Track = { Id: number, Name: string }

local Playlists: { Volume: number, Lobby: { Track }, Race: { Track } } = {
	Volume = 0.35,
	Lobby = {
		{ Id = 1840556856, Name = "The Ramblers' String Band Special" },
		{ Id = 1842188764, Name = "Way Out West" },
		{ Id = 1838909465, Name = "Joyful Country" },
		{ Id = 1839865028, Name = "Country Kids" },
		{ Id = 9040428605, Name = "Casual Living" },
	},
	Race = {
		{ Id = 1842334470, Name = "Barnyard Boogie" },
		{ Id = 1838909565, Name = "Lively Country" },
		{ Id = 1845958925, Name = "The Blackthorn Stick" },
		{ Id = 1844692318, Name = "Polkas Forever" },
	},
}

return Playlists
