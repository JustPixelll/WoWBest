from pathlib import Path
import sys
import unittest

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / 'tools'))
from build_tooltip_stats import facts


class TooltipFactsTests(unittest.TestCase):
    def test_separate_numeric_rows_from_proc_set_and_temporary_stats(self):
        # Zandalar Haruspex's Tunic, 19838: +33 healing is passive. MP5
        # belongs to its two-piece and the three-piece changes a spell duration.
        tip = """<!--scstart4:2--><!--amr-->197 Armor<span><!--stat50-->+90 Armor</span>
        <span class="q2">Equip: Increases healing done by magical spells and effects by up to <span>33</span>.</span>
        <span class="q2">(2) Set : Restores 4 mana per 5 sec.</span>
        <span class="q2">(3) Set : Increases the duration of Faerie Fire by 5 sec.</span>
        <span class="q2">Equip: +19 Attack Power against Beasts.</span>
        <span class="q2">Use: +12 Attack Power.</span>
        <span class="q2">Equip: <a>Chance on hit: +30 Attack Power.</a></span>"""
        self.assertEqual(facts({"tooltipHtml": tip}), {"armor": 197, "extraArmor": 90, "heal": 33, "proc": 1})

    def test_linked_proc_cannot_become_unconditional_spell_power(self):
        tip = """<!--scstart2:10--><span class="q2">Equip: Increases damage and healing done by magical spells and effects by up to <span>54</span>.</span>
        <span id="useText1" class="q2">Equip: <a>Chance on harmful spell cast to summon a Zombie Troll of Zum'rah for 20 sec. (1m cooldown)</a></span>"""
        self.assertEqual(facts({"tooltipHtml": tip}), {"shared": 54, "proc": 1})
