import sys
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "tools" / "tea_agent_tools"))

from tea_business_tool_server import (  # noqa: E402
    classify_question,
    generate_sales_script,
    handle_customer,
    query_inventory,
    recommend_tea,
)


class TeaBusinessToolsTest(unittest.TestCase):
    def test_recommend_tea_for_gift_budget(self):
        result = recommend_tea(
            {
                "budget": 300,
                "taste": "温和",
                "purpose": "送礼",
                "crowd": "长辈",
                "gift": True,
            }
        )

        self.assertEqual(result["tool_name"], "recommend_tea")
        self.assertGreaterEqual(len(result["recommendations"]), 1)
        top = result["recommendations"][0]
        self.assertLessEqual(top["price"], 300)
        self.assertIn("brew_suggestion", top)

    def test_generate_sales_script_returns_stable_steps(self):
        result = generate_sales_script(
            {
                "budget": 300,
                "taste": "温和",
                "purpose": "送礼",
                "crowd": "长辈",
                "customer_need": "客户想给长辈买茶",
            }
        )

        self.assertEqual(result["tool_name"], "generate_sales_script")
        self.assertGreaterEqual(len(result["script"]), 4)
        self.assertIn("risk_notice", result)

    def test_query_inventory_by_category(self):
        result = query_inventory({"product_name": "红茶"})

        self.assertEqual(result["tool_name"], "query_inventory")
        self.assertEqual(len(result["items"]), 1)
        self.assertEqual(result["items"][0]["name"], "桂香工夫红茶")

    def test_classify_health_question_requires_caution(self):
        result = classify_question({"question": "茶叶有没有治疗高血压的作用？"})

        self.assertEqual(result["question_type"], "health_risk")
        self.assertTrue(result["need_human"])

    def test_handle_customer_routes_gift_question_to_recommend_tool(self):
        result = handle_customer(
            {
                "question": "客户预算300元，想送长辈，应该推荐哪款茶？",
                "budget": 300,
                "purpose": "送礼",
                "crowd": "长辈",
                "gift": True,
            }
        )

        self.assertEqual(result["tool_name"], "handle_customer")
        self.assertEqual(result["classification"]["question_type"], "product_consulting")
        self.assertEqual(result["tool_result"]["tool_name"], "recommend_tea")


if __name__ == "__main__":
    unittest.main()
