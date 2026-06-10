"""HTTP tools for the tea garden business assistant.

The service is intentionally dependency-free so it can run in a demo machine
without installing FastAPI or Flask. RAGFlow Agent/Workflow can call these
endpoints as HTTP tools.
"""

from __future__ import annotations

import argparse
import json
import re
import time
from dataclasses import dataclass
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from typing import Any
from urllib.parse import urlparse


@dataclass(frozen=True)
class TeaProduct:
    name: str
    category: str
    price: int
    stock: int
    taste_tags: tuple[str, ...]
    scene_tags: tuple[str, ...]
    crowd_tags: tuple[str, ...]
    brew: str
    selling_points: tuple[str, ...]
    cautions: tuple[str, ...]


PRODUCTS: tuple[TeaProduct, ...] = (
    TeaProduct(
        name="高山云雾绿茶",
        category="绿茶",
        price=168,
        stock=42,
        taste_tags=("清爽", "鲜爽", "不苦", "新手"),
        scene_tags=("日常", "自饮", "办公室"),
        crowd_tags=("新手", "年轻客户", "清淡口味"),
        brew="建议 80-85 摄氏度水温，投茶 3g，先快出汤，避免闷泡导致苦涩。",
        selling_points=("口感清爽", "适合新手", "日常饮用成本适中"),
        cautions=("不承诺治疗疾病", "胃寒客户建议少量饮用"),
    ),
    TeaProduct(
        name="桂香工夫红茶",
        category="红茶",
        price=298,
        stock=18,
        taste_tags=("香甜", "醇厚", "温和"),
        scene_tags=("送礼", "商务", "长辈", "冬季"),
        crowd_tags=("长辈", "商务客户", "偏好温和口感"),
        brew="建议 90-95 摄氏度水温，投茶 4g，可冲泡 5-7 次，前两泡控制在 10 秒左右。",
        selling_points=("香气明显", "口感温和", "礼盒预算友好"),
        cautions=("库存有限", "不夸大保健功效"),
    ),
    TeaProduct(
        name="陈香老白茶",
        category="白茶",
        price=368,
        stock=12,
        taste_tags=("陈香", "柔和", "回甘"),
        scene_tags=("送礼", "长辈", "收藏", "健康茶饮"),
        crowd_tags=("长辈", "老茶客", "偏好柔和口感"),
        brew="可用 95 摄氏度以上热水冲泡，也可煮饮；前期快出汤，后期适当延长浸泡时间。",
        selling_points=("口感柔和", "适合长辈", "有陈化风味"),
        cautions=("只说明茶饮属性", "不宣传医疗效果"),
    ),
    TeaProduct(
        name="茉莉花茶",
        category="再加工茶",
        price=128,
        stock=35,
        taste_tags=("花香", "清香", "清爽", "新手"),
        scene_tags=("日常", "办公室", "女性客户", "自饮"),
        crowd_tags=("新手", "女性客户", "花香偏好"),
        brew="建议 85 摄氏度左右水温，避免长时间闷泡，花香更清晰。",
        selling_points=("花香接受度高", "价格亲民", "适合作为入门茶"),
        cautions=("香气偏好因人而异", "不建议过度推荐给不喜花香的客户"),
    ),
    TeaProduct(
        name="岩韵乌龙茶",
        category="乌龙茶",
        price=458,
        stock=8,
        taste_tags=("岩韵", "醇厚", "回甘", "老茶客"),
        scene_tags=("商务", "送礼", "高端", "品鉴"),
        crowd_tags=("老茶客", "商务客户", "重口味"),
        brew="建议 95 摄氏度以上沸水冲泡，快进快出，可用盖碗突出香气和层次。",
        selling_points=("层次感强", "适合品鉴", "送礼档次较高"),
        cautions=("不适合预算较低客户", "新手可能觉得口感偏重"),
    ),
)


QUESTION_TYPES = {
    "product_consulting": ("产品", "茶品", "哪款", "推荐", "适合", "口感"),
    "brew_consulting": ("冲泡", "水温", "泡", "投茶", "闷泡"),
    "gift_recommendation": ("送礼", "领导", "长辈", "商务", "礼盒"),
    "price_inventory": ("价格", "多少钱", "库存", "有货", "预算"),
    "after_sales": ("售后", "退货", "换货", "发票", "物流"),
    "health_risk": ("治疗", "高血压", "糖尿病", "药", "疗效", "治病"),
}


def _now_ms(start: float) -> int:
    return int((time.perf_counter() - start) * 1000)


def _normalize_text(value: Any) -> str:
    return str(value or "").strip()


def _request_tags(payload: dict[str, Any]) -> set[str]:
    tags: set[str] = set()
    for key in ("taste", "purpose", "crowd"):
        value = _normalize_text(payload.get(key))
        if value:
            tags.add(value)
    if payload.get("gift"):
        tags.add("送礼")
    if payload.get("beginner"):
        tags.add("新手")
    return tags


def _augment_payload_from_question(payload: dict[str, Any]) -> dict[str, Any]:
    enriched = dict(payload)
    question = _normalize_text(enriched.get("question") or enriched.get("customer_need"))
    if not question:
        return enriched

    budget_match = re.search(r"(\d{2,5})\s*元", question)
    if budget_match and not enriched.get("budget"):
        enriched["budget"] = int(budget_match.group(1))

    if any(word in question for word in ("送", "礼", "礼盒", "领导", "长辈", "客户")):
        enriched["gift"] = True
        enriched.setdefault("purpose", "送礼")
    if "长辈" in question:
        enriched.setdefault("crowd", "长辈")
    elif "领导" in question:
        enriched.setdefault("crowd", "领导")
    elif "客户" in question or "商务" in question:
        enriched.setdefault("crowd", "商务客户")

    if any(word in question for word in ("新手", "入门")):
        enriched["beginner"] = True
        enriched.setdefault("crowd", "新手")
    if any(word in question for word in ("怕苦", "不苦")):
        enriched.setdefault("taste", "不苦")
    elif "温和" in question:
        enriched.setdefault("taste", "温和")
    elif "清甜" in question:
        enriched.setdefault("taste", "清甜")
    elif "清爽" in question:
        enriched.setdefault("taste", "清爽")
    elif "浓" in question or "醇厚" in question:
        enriched.setdefault("taste", "醇厚")

    if "办公室" in question:
        enriched.setdefault("purpose", "办公室")
    elif "冷泡" in question or "夏天" in question or "夏季" in question:
        enriched.setdefault("purpose", "夏季")
    elif "商务" in question or "领导" in question:
        enriched.setdefault("purpose", "商务")
    elif "套餐" in question or "搭配" in question:
        enriched.setdefault("purpose", "套餐")

    for product in PRODUCTS:
        if product.name in question:
            enriched.setdefault("product_name", product.name)
            break
    return enriched


def _score_product(product: TeaProduct, payload: dict[str, Any]) -> tuple[int, list[str]]:
    budget = int(payload.get("budget") or 0)
    tags = _request_tags(payload)
    score = 0
    reasons: list[str] = []

    if budget and product.price <= budget:
        score += 4
        reasons.append(f"价格 {product.price} 元，符合 {budget} 元预算")
    elif budget:
        score -= 3
        reasons.append(f"价格 {product.price} 元，高于 {budget} 元预算")

    for tag in tags:
        if tag in product.taste_tags or tag in product.scene_tags or tag in product.crowd_tags:
            score += 3
            reasons.append(f"匹配“{tag}”需求")
        if tag == "送礼" and ("礼盒" in product.name or "礼盒" in product.scene_tags):
            score += 2
            reasons.append("适合礼盒送礼")
        if tag == "套餐" and "组合" in product.name:
            score += 5
            reasons.append("适合作为茶叶套餐")

    if product.stock > 20:
        score += 1
        reasons.append("库存充足")
    elif product.stock <= 10:
        reasons.append("库存较少，适合提醒客户尽快确认")

    return score, reasons


def recommend_tea(payload: dict[str, Any]) -> dict[str, Any]:
    start = time.perf_counter()
    payload = _augment_payload_from_question(payload)
    scored = []
    for product in PRODUCTS:
        score, reasons = _score_product(product, payload)
        scored.append((score, product, reasons))
    scored.sort(key=lambda item: (item[0], -item[1].price), reverse=True)

    question = _normalize_text(payload.get("question") or payload.get("customer_need"))
    recommendations = []
    if ("套餐" in question or "搭配" in question) and int(payload.get("budget") or 0) >= 290:
        combo = [p for p in PRODUCTS if p.name in {"茉莉花茶", "高山云雾绿茶"}]
        if len(combo) == 2:
            total_price = sum(p.price for p in combo)
            recommendations.append(
                {
                    "name": "茉莉花茶 + 高山云雾绿茶",
                    "category": "组合套餐",
                    "price": total_price,
                    "stock": min(p.stock for p in combo),
                    "score": 99,
                    "recommend_reasons": [f"两款合计 {total_price} 元，接近 300 元预算", "一款花香、一款清爽，组合层次更丰富"],
                    "brew_suggestion": "茉莉花茶建议 85 摄氏度左右水温；高山云雾绿茶建议 80-85 摄氏度水温，均避免长时间闷泡。",
                    "selling_points": ["价格贴近预算", "口味组合丰富", "适合日常茶叶套餐"],
                    "cautions": ["如客户明确要求单品礼盒，可优先推荐桂香工夫红茶或礼盒组合A"],
                }
            )

    for score, product, reasons in scored[:3]:
        if any(item["name"] == product.name for item in recommendations):
            continue
        recommendations.append(
            {
                "name": product.name,
                "category": product.category,
                "price": product.price,
                "stock": product.stock,
                "score": score,
                "recommend_reasons": reasons[:4],
                "brew_suggestion": product.brew,
                "selling_points": list(product.selling_points),
                "cautions": list(product.cautions),
            }
        )
        if len(recommendations) >= 3:
            break

    return {
        "tool_name": "recommend_tea",
        "recommendations": recommendations,
        "sales_note": "推荐时只按资料说明茶饮体验和适用场景，不承诺治疗疾病或固定功效。",
        "latency_ms": _now_ms(start),
    }


def generate_sales_script(payload: dict[str, Any]) -> dict[str, Any]:
    start = time.perf_counter()
    payload = _augment_payload_from_question(payload)
    rec = recommend_tea(payload)["recommendations"][0]
    customer_need = _normalize_text(payload.get("customer_need")) or "客户正在咨询茶叶选择"
    budget = _normalize_text(payload.get("budget")) or "未说明"
    scene = _normalize_text(payload.get("purpose")) or "日常咨询"

    script = [
        f"您这个需求我建议先看 {rec['name']}，它比较适合{scene}场景。",
        f"这款茶当前参考价 {rec['price']} 元，您的预算是 {budget}，整体匹配度比较高。",
        f"它的主要特点是：{'、'.join(rec['selling_points'])}。",
        f"冲泡上可以这样做：{rec['brew_suggestion']}",
        "如果您更在意口感、送礼档次或预算控制，我可以再帮您换一个方向对比。",
    ]

    return {
        "tool_name": "generate_sales_script",
        "customer_need": customer_need,
        "recommended_product": rec["name"],
        "script": script,
        "follow_up_questions": ["客户更看重口感还是送礼档次？", "预算是否需要控制在固定区间？", "收礼人平时是否喝茶？"],
        "risk_notice": "涉及健康功效时，只能描述茶饮资料中的一般说法，不能承诺治疗效果。",
        "latency_ms": _now_ms(start),
    }


def query_inventory(payload: dict[str, Any]) -> dict[str, Any]:
    start = time.perf_counter()
    payload = _augment_payload_from_question(payload)
    name = _normalize_text(payload.get("product_name") or payload.get("question"))
    matched = [
        product
        for product in PRODUCTS
        if not name or name in product.name or product.name in name or product.category in name
    ]
    if not matched:
        return {
            "tool_name": "query_inventory",
            "query": name,
            "items": [],
            "message": "当前工具数据中未确认该茶品的价格和库存，可根据客户预算、口味和用途推荐替代产品。",
            "alternatives": [item.name for item in PRODUCTS[:3]],
            "latency_ms": _now_ms(start),
        }

    return {
        "tool_name": "query_inventory",
        "query": name,
        "items": [
            {
                "name": item.name,
                "category": item.category,
                "price": item.price,
                "stock": item.stock,
                "status": "有货" if item.stock > 0 else "缺货",
                "suggested_pairing": item.brew,
            }
            for item in matched
        ],
        "latency_ms": _now_ms(start),
    }


def classify_question(payload: dict[str, Any]) -> dict[str, Any]:
    start = time.perf_counter()
    question = _normalize_text(payload.get("question"))
    hits = []
    for qtype, keywords in QUESTION_TYPES.items():
        if any(keyword in question for keyword in keywords):
            hits.append(qtype)

    qtype = hits[0] if hits else "knowledge_base_question"
    need_human = qtype in {"after_sales", "health_risk"} or "投诉" in question
    next_action = {
        "product_consulting": "调用茶叶推荐工具，并结合知识库补充茶品特点。",
        "brew_consulting": "优先检索知识库中的冲泡资料，再生成步骤化建议。",
        "gift_recommendation": "调用茶叶推荐工具，重点考虑预算、人群和送礼场景。",
        "price_inventory": "调用价格库存查询工具，避免模型编造价格或库存。",
        "after_sales": "转人工或按售后政策资料回答。",
        "health_risk": "避免医疗承诺，只能说明资料中的一般茶饮信息。",
        "knowledge_base_question": "走 RAG 知识库问答。",
    }[qtype]

    return {
        "tool_name": "classify_question",
        "question": question,
        "question_type": qtype,
        "matched_types": hits,
        "need_human": need_human,
        "next_action": next_action,
        "latency_ms": _now_ms(start),
    }


def handle_customer(payload: dict[str, Any]) -> dict[str, Any]:
    start = time.perf_counter()
    payload = _augment_payload_from_question(payload)
    question = _normalize_text(payload.get("question"))
    classified = classify_question({"question": question})

    if classified["question_type"] == "price_inventory":
        tool_result = query_inventory({"product_name": question})
    elif classified["question_type"] == "brew_consulting":
        tool_result = query_inventory({"product_name": question})
    elif classified["question_type"] in {"product_consulting", "gift_recommendation"}:
        merged_payload = dict(payload)
        if classified["question_type"] == "gift_recommendation":
            merged_payload["gift"] = True
        tool_result = recommend_tea(merged_payload)
    elif classified["question_type"] == "health_risk":
        tool_result = {
            "tool_name": "health_risk_guardrail",
            "answer_policy": "不能承诺治疗效果，不能建议替代药物或停药。只能说明茶是日常饮品，并建议健康问题咨询医生。",
            "need_human": True,
        }
    elif classified["question_type"] == "after_sales":
        tool_result = {
            "tool_name": "after_sales_policy",
            "policies": [
                "库存和价格以实际成交前确认为准。",
                "未拆封且不影响二次销售的产品可按门店政策处理。",
                "食品类产品拆封后需谨慎确认，建议转人工处理。",
            ],
        }
    else:
        tool_result = {
            "tool_name": "rag_required",
            "message": "该问题应进入 RAGFlow 知识库问答链路，工具只给出分流建议。",
        }

    return {
        "tool_name": "handle_customer",
        "classification": classified,
        "tool_result": tool_result,
        "latency_ms": _now_ms(start),
    }


OPENAPI_SPEC = {
    "openapi": "3.0.3",
    "info": {"title": "Tea Garden Business Agent Tools", "version": "1.0.0"},
    "servers": [{"url": "http://127.0.0.1:18088"}],
    "paths": {
        "/tools/recommend_tea": {"post": {"summary": "Recommend tea products by budget, taste, crowd and scene."}},
        "/tools/generate_sales_script": {"post": {"summary": "Generate a customer-facing sales script."}},
        "/tools/query_inventory": {"post": {"summary": "Query demo price and inventory by tea product name."}},
        "/tools/classify_question": {"post": {"summary": "Classify customer question and suggest next action."}},
        "/agent/handle_customer": {"post": {"summary": "Route a customer question to the proper business tool."}},
    },
}


ROUTES = {
    "/tools/recommend_tea": recommend_tea,
    "/tools/generate_sales_script": generate_sales_script,
    "/tools/query_inventory": query_inventory,
    "/tools/classify_question": classify_question,
    "/agent/handle_customer": handle_customer,
}


class TeaToolHandler(BaseHTTPRequestHandler):
    def _send_json(self, status: int, payload: dict[str, Any]) -> None:
        body = json.dumps(payload, ensure_ascii=False, indent=2).encode("utf-8")
        self.send_response(status)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def do_GET(self) -> None:
        path = urlparse(self.path).path
        if path == "/health":
            self._send_json(200, {"status": "ok", "service": "tea-agent-tools"})
            return
        if path == "/openapi.json":
            self._send_json(200, OPENAPI_SPEC)
            return
        self._send_json(404, {"error": "not_found", "path": path})

    def do_POST(self) -> None:
        path = urlparse(self.path).path
        if path not in ROUTES:
            self._send_json(404, {"error": "not_found", "path": path})
            return

        try:
            content_length = int(self.headers.get("Content-Length") or 0)
            raw_body = self.rfile.read(content_length) if content_length else b"{}"
            payload = json.loads(raw_body.decode("utf-8") or "{}")
            if not isinstance(payload, dict):
                raise ValueError("JSON body must be an object")
            self._send_json(200, ROUTES[path](payload))
        except Exception as exc:  # noqa: BLE001 - tool API should return JSON errors.
            self._send_json(400, {"error": "bad_request", "message": str(exc)})

    def log_message(self, fmt: str, *args: Any) -> None:
        print(f"[tea-agent-tools] {self.address_string()} - {fmt % args}")


def main() -> None:
    parser = argparse.ArgumentParser(description="Tea garden business HTTP tools")
    parser.add_argument("--host", default="127.0.0.1")
    parser.add_argument("--port", default=18088, type=int)
    args = parser.parse_args()

    server = ThreadingHTTPServer((args.host, args.port), TeaToolHandler)
    print(f"Tea agent tools listening on http://{args.host}:{args.port}")
    server.serve_forever()


if __name__ == "__main__":
    main()
