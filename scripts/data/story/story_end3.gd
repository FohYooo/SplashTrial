extends RefCounted
## Chapter 3 ("Murder at Warden's Rest") ending scripts (SPOILERS). The flow after a correct final vote is
## confession (story id "confession", on the courtroom stage; written with the trial, optional) -> execution
## (execution3_screen.gd) -> epilogue -> caiman_kill (caiman_kill_screen.gd) -> epilogue_after -> credits.
## Backgrounds end3_* come from tools/gen_end3_art.py. Design notes: docs/DESIGN3.md, "Endings".

const SCRIPTS := {
	"epilogue": """
@bg end3_hall
@music sad
narr: When it was over, Snapjaw marched us back up the cliff path to the Warden's Rest. Nine of us. Nobody said a word the whole way.
narr: He didn't let us go to bed. He sat us down on the great staircase in the Grand Hall, in a row, like a school photograph.
@show snapjaw happy center
snapjaw[happy]: Snap-snap-snap! One last bedtime story before lights out, my darlings. About my Ledger.
snapjaw[happy]: You tore this house apart over it! Locked doors! Burned pages! Old friends who won't pass each other the salt!
snapjaw[normal]: Every tip in that book came from one source. One hard-working little typist who sold to my agency for years and never once asked what for.
snapjaw[happy]: And the names at the bottom of each line? I typed those myself. Last week. On the old machine in the prison office.
snapjaw[happy]: All but one. One line in that whole book was true. Zuzu, would you like to guess which?
@show zuzu sad farright
zuzu[sad]: ...mine. my mum. the one she read out at breakfast.
snapjaw[happy]: The only true line in the book! And she read it to you over toast without a flicker. What a professional.
@hide zuzu
@show duchess sad farleft
duchess[sad]: Then Professor Nibs never... He never informed on Plum. He never informed on anybody.
@show reginald sad farright
reginald[sad]: Nor on my mother. And I spent three days unable to look at the man.
@hide all
@show snapjaw happy center
@show lulu sad farleft
lulu[sad]: ...Bramble?
narr: Bramble looked at her for a long moment. Then she looked away.
@hide lulu
snapjaw[happy]: Nobody at that table ever betrayed anybody! You only believed you had. Isn't that FUNNY? I laughed for days.
narr: Nobody laughed.
think: Grub hadn't sat down with the rest of us. He was standing at the foot of the stairs, swaying, his bandaged paw held against his chest.
narr: He must have gone down to the kitchen while Snapjaw was talking. Nobody had seen him go. He was holding the big cleaver.
snapjaw[happy]: And our chef! Named against Bruno's little student, weren't you? Forged, naturally. You've been terribly quiet tonight, Grub.
@show grub angry farleft
grub[angry]: ...You.
grub[angry]: You. Did. All of it.
@show bruno shock farright
bruno[shock]: Grub? Grub, put it down. Bruno will help. Bruno will...
@end
""",

	"epilogue_after": """
@bg end3_hall_after
@music stop
narr: It was over in seconds. Then it was very, very quiet.
narr: The cleaver lay on the marble where it had spun to a stop. Grub's chef's hat lay a little further off, upside down.
@show snapjaw normal center
narr: Snapjaw took a folded handkerchief from his breast pocket and wiped his chin. Slowly. Thoroughly.
snapjaw[normal]: Rule 6. No violence against Warden Snapjaw.
snapjaw[normal]: I did put it in writing.
@sfx door
@hide snapjaw
narr: His footsteps went all the way up the stairs. Somewhere above us, a door closed.
narr: Nobody moved for a long time.
mochi: ...Rabies.
narr: It was the first time anyone had said it out loud.
think: The bandage. The soup he wouldn't taste. The ladle he couldn't keep still. Standing over Lulu in the night, with no memory of it.
think: A capybara who won't go near water. I'm the Ace Bath Connoisseur. I noticed that on the second day, and I didn't say anything, because I didn't want it to be true.
@show bruno sad center
bruno[sad]: Bruno told everyone Grub was with Bruno. In the trial. Bruno lied, to keep him safe.
bruno[sad]: Bruno should have carried him to the wreck. To the infirmary. To anywhere. Bruno only sat with him.
@hide all
@show reginald sad farleft
@show zuzu sad farright
narr: Reginald looked down at the bandage on his own paw. So did Zuzu. Without a word, they both began to unwind them.
narr: Under each one was a small, clean, pink scar. Healed. Neither of them said anything. Neither of them needed to.
@hide all
@show lulu sad farleft
@show bramble sad farright
narr: Lulu and Bramble sat at opposite ends of the bottom stair.
narr: The page that broke them had been a forgery. They both knew that now. It didn't seem to help. Neither of them spoke.
@hide all
narr: Later, somebody had to go into the kitchen. It was Reginald.
narr: He came back with a plate of toast and set it down on the step beside Bruno, without looking at him. Then he went and sat somewhere else.
narr: Bruno looked at the plate for a long time. Then he ate it. That was as far as it went.
@show duchess sad center
duchess[sad]: He made such dreadful soup, at the end. I told him so, darlings. I'd give anything to tell him again.
@hide all
@show fennel sad center
fennel[sad]: I will paint him. In his hat, with a ladle, scolding us for letting it go cold. As he was. Before.
@hide all
@bg end3_terrace
@music sad
narr: In the end we went out onto the terrace, because nobody could stand to stay in that hall.
narr: Across the water, the Gaol sat black against the sky. Every cell had its little light. By now we all knew which one was ours.
think: Nibs. Pepper. Grub. Three empty places at the table tomorrow, and no Grub to set them.
@wait 1.5
@bg end3_terrace_out
@wait 1
narr: Then, while we were watching, one of the lights went out.
narr: Nobody asked whose. Nobody could bear to count.
think: Eleven of us came off the Mudlark. Eight of us are left.
think: Nobody at that table ever betrayed anybody. One of us sold all of us, without knowing what she was selling, and killed a friend rather than let him find out.
think: And somewhere in that book there's still a line with the name torn off. Grandma's line.
think: Whoever is behind that red eye, I'm going to find them. For Nibs. For Grub. And for the lights over there that are still on.
@card CHAPTER 3 — END | 8 guests remain at the Warden's Rest
@end
""",
}
