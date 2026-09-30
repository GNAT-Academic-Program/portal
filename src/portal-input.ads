--  Portal.Input: keys, modifiers, mouse and gamepad vocabulary. These
--  live in bedrock so that every GAP project shares one Key; this
--  renaming keeps Portal.Input.Key spelled the way the ports and the
--  docs say it.

with Bedrock.Input;

package Portal.Input renames Bedrock.Input;
