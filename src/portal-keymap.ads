--  Portal.Keymap: physical key names
--  Physical keys: XKB key name -> Key, independent of the layout.
--  Names shorter than 4 characters are padded with spaces.

with Portal.Input;

package Portal.Keymap is

   subtype Key_Name is String (1 .. 4);

   function Key_From_Name (Name : Key_Name) return Portal.Input.Key;

end Portal.Keymap;
