Clique is a simple addon that enables powerful click-casting and hover-casting on your unit frames and in the 3D game world. You can bind virtually any mouse or keyboard combination to a spell or macro. In it's normal configuration this enables you to use the bindings over your unit frames in order to cast spells directly on that unit. This allows you to more quickly select both the spell to cast, and the target of the spell without requiring an extra click.

To begin with Clique, open your spellbook and click on the new tab that is shown there. You can also open the configuration GUI by running the /clique slash command. From this binding interface you can add, remove and alter any of your Clique bindings. You will be unable to make these changes when you are in combat due to limitations in the Blizzard API.

# Binding a spell

Binding a spell is just a matter of finding the spell in your spellbook, putting your mouse over it, and performing the binding you would like to add. For example, if you'd like to set 'Regrowth' to activate on 'Shift-LeftButton', then you just find that spell in your spellbook and then Shift-LeftClick on it. You can also bind keyboard combinations, so you could do the same with Shift-R if you'd like.

*Keep in mind when you are setting your bindings that they will override any bindings that are already set on the frame, for example the default bindings to 'Target unit' and 'Show unit menu'. You can override these bindings if you would like, but you should then set a new different combination that will activate the original functions*

## Binding the 'Target unit' or 'Show unit menu' actions

If you've rebound or lose these default bindings, you can re-bind them using the 'Bind other' button in the Clique configuration. Click on the button, and choose the correct action and you will be presented with a dialog box that allows you to set the binding for that action. Simply choose a new key combination, and you will be able to target units and open your menu again.

## Binding a macro

Binding a macro can also be found on the 'Bind other' button. You'll be given a new window with instructions and suggestions about writing your macros, but other than that the process should seem very similar.

## Managing click-sets

Each binding can belong to a number of binding-sets. These sets determine when the binding is active. The built-in binding-sets are as follows:

* default - This set is always active on registered unit frames, unless overridden by another binding-set.
* ooc - This set is only active when you are out of combat. Once you begin fighting, these bindings will no longer be active, regardless of what other bind-sets are selected.
* friend - This set is only active when you are activating a binding on a friendly unit, i.e. one you can assist.
* enemy - This set is only active when you are activating a binding on an enemy unit, i.e. one you can attack.
* hovercast - These bindings will be available whenever you are over a unit frame, or a unit in the 3D world.
* global - These bindings will be always available. They do not specify a target for the action, so if the action requires a target, you must specify it after performing the binding.
* Talent: SpecName - When any talent bind set is selected, that binding will only be active when that talent specialization is active, regardless of other bind sets. A binding can be set for more than one talent spec at a time and it should function correctly.

## Clique and dual talent specs
In addition Clique allows you to set up different profiles, and can automatically switch between them when your character changes talent groups.  In order to set this up, click the 'Options' button, or navigate to the Clique options section of the Interface Options menu. Here you can create new profiles and change your options to activate different profiles depending on talent spec.

## Bug reports:
If you are going to submit a bug report, please include the following information:
* What version of Clique you are using (/dump Clique.version)
* What unit frames you are using
* What specific bindings are not working

Some folks have asked for how they can donate money, and for many years I've enjoyed hearing about how my addons have helped other people enjoy World of Warcraft. If you would like to donate, I'd ask you to make a donation to the [Colorectal Cancer Alliance](https://www.ccalliance.org/donate), a worthy organisation that helped my sister immensely from her diagnosis through her final years. If you or a family member suspect you might have something not right in your butt, please have a doctor check it out. Colorectal cancer is one of the most preventable cancers in the world.

This repository is source-available but not open source.
All rights are reserved.
