--  Portal.Events: the Event a port delivers and the queue it goes in.
--  Same package as Portal.Input (bedrock keeps them together); two
--  names so `with Portal.Events; use Portal.Events;` reads as before.

with Bedrock.Input;

package Portal.Events renames Bedrock.Input;
