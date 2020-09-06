// Add UnityEditor namespace.
using UnityEditor;
using UnityEngine;

// Inherit from the parent class EditorWindow.
public class EditorWindowTemplate : EditorWindow
{
    // Affix a menu item attribute to a static function. The path specifies
    // where the menu is located in the editor.
    [MenuItem ("Window/My Editor")]
    static void Init ( )
    {
        // Get the window, cast it from a generic EditorWindow
        // to the specific child class. Show the window.
        EditorWindowTemplate window = (EditorWindowTemplate) EditorWindow.GetWindow (
            t: typeof (EditorWindowTemplate),
            utility: false,
            title: "My Editor",
            focus : true);
        window.Show ( );
    }

    void OnGUI ( )
    {
        // Create input fields and buttons with EditorGUILayout here.
        // Use AssetDatabase to save any assets created to project.
        EditorGUILayout.HelpBox ("Hello world!", MessageType.Info);
    }
}