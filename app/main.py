import os
import json
import html
from bottle import Bottle, request, response
import fitz  # PyMuPDF
import pandas as pd
import pdfplumber
from pdf2docx import Converter
from PIL import Image
from docx import Document
from htmldocx import HtmlToDocx
from pptx import Presentation
from pptx.util import Inches, Pt
from pptx.dml.color import RGBColor

app = Bottle()

def json_res(data, code=200):
    response.content_type = 'application/json'
    response.status = code
    return json.dumps(data)

@app.route('/health', method='GET')
def health():
    return json_res({"status": "running"})

# 1. Convert Excel / CSV to Predefined Quiz HTML Format
@app.route('/convert/sheet-to-html', method='POST')
def sheet_to_html():
    try:
        data = request.json
        input_path = data.get("input_path")
        output_path = data.get("output_path")

        if input_path.endswith(('.xlsx', '.xls')):
            df = pd.read_excel(input_path)
        else:
            df = pd.read_csv(input_path)

        df.columns = [str(c).strip().lower() for c in df.columns]

        def find_col(aliases, default=""):
            for col in df.columns:
                for alias in aliases:
                    if alias in col:
                        return col
            return default

        col_q_num = find_col(["number", "num", "q_no", "id"])
        col_question = find_col(["question", "q_text", "prompt"])
        col_opt_a = find_col(["option a", "opt a", "opt_a", "a)"])
        col_opt_b = find_col(["option b", "opt b", "opt_b", "b)"])
        col_opt_c = find_col(["option c", "opt c", "opt_c", "c)"])
        col_opt_d = find_col(["option d", "opt d", "opt_d", "d)"])
        col_correct = find_col(["correct", "ans", "answer"])
        col_explanation = find_col(["explanation", "exp", "reason"])

        html_blocks = []

        for index, row in df.iterrows():
            q_num = index + 1
            if col_q_num and pd.notna(row[col_q_num]):
                try:
                    q_num = int(row[col_q_num])
                except (ValueError, TypeError):
                    q_num = index + 1

            q_id = f"question{q_num}"
            raw_q_text = str(row[col_question]) if col_question and pd.notna(row[col_question]) else ""
            
            if not raw_q_text.lower().startswith("question"):
                q_title = f"Question {q_num}: {raw_q_text.strip()}"
            else:
                q_title = raw_q_text.strip()

            correct_letter = str(row[col_correct]).strip().upper() if col_correct and pd.notna(row[col_correct]) else ""

            def clean_option(val):
                text = str(val).strip() if pd.notna(val) else ""
                if len(text) >= 3 and text[0].upper() in ['A', 'B', 'C', 'D'] and text[1] in [')', '.', ':']:
                    text = text[2:].strip()
                return html.escape(text)

            opt_a = clean_option(row.get(col_opt_a, ""))
            opt_b = clean_option(row.get(col_opt_b, ""))
            opt_c = clean_option(row.get(col_opt_c, ""))
            opt_d = clean_option(row.get(col_opt_d, ""))

            is_a_correct = "true" if "A" in correct_letter else "false"
            is_b_correct = "true" if "B" in correct_letter else "false"
            is_c_correct = "true" if "C" in correct_letter else "false"
            is_d_correct = "true" if "D" in correct_letter else "false"

            raw_exp = str(row[col_explanation]).strip() if col_explanation and pd.notna(row[col_explanation]) else ""
            if raw_exp and not raw_exp.lower().startswith("explanation:"):
                exp_text = f"Explanation: {raw_exp}"
            else:
                exp_text = raw_exp or "Explanation: N/A"

            block = f"""            <br />
            <div class="question" id="{q_id}">{html.escape(q_title)}</div>
            <div class="option" data-correct="{is_a_correct}" data-question="{q_id}">A) {opt_a}</div>
            <div class="option" data-correct="{is_b_correct}" data-question="{q_id}">B) {opt_b}</div>
            <div class="option" data-correct="{is_c_correct}" data-question="{q_id}">C) {opt_c}</div>
            <div class="option" data-correct="{is_d_correct}" data-question="{q_id}">D) {opt_d}</div>
            <div class="explanation" data-question="{q_id}">{html.escape(exp_text)}</div>"""
            
            html_blocks.append(block)

        final_html = "\n".join(html_blocks) + "\n            <br />\n"

        with open(output_path, "w", encoding="utf-8") as f:
            f.write(final_html)

        return json_res({"success": True, "output": output_path})
    except Exception as e:
        return json_res({"error": str(e)}, 500)

# 2. PDF Merge
@app.route('/pdf/merge', method='POST')
def merge_pdfs():
    try:
        data = request.json
        file_paths = data.get("file_paths", [])
        output_path = data.get("output_path")

        merged_doc = fitz.open()
        for path in file_paths:
            doc = fitz.open(path)
            merged_doc.insert_pdf(doc)
            doc.close()

        merged_doc.save(output_path)
        merged_doc.close()
        return json_res({"success": True, "output": output_path})
    except Exception as e:
        return json_res({"error": str(e)}, 500)

# 3. PDF Split
@app.route('/pdf/split', method='POST')
def split_pdf():
    try:
        data = request.json
        input_path = data.get("input_path")
        output_path = data.get("output_path")
        start_page = int(data.get("start_page", 1)) - 1
        end_page = int(data.get("end_page", 1)) - 1

        doc = fitz.open(input_path)
        split_doc = fitz.open()
        split_doc.insert_pdf(doc, from_page=start_page, to_page=end_page)
        split_doc.save(output_path)
        doc.close()
        split_doc.close()

        return json_res({"success": True, "output": output_path})
    except Exception as e:
        return json_res({"error": str(e)}, 500)

# 4. Images to PDF
@app.route('/pdf/images-to-pdf', method='POST')
def images_to_pdf():
    try:
        data = request.json
        image_paths = data.get("image_paths", [])
        output_path = data.get("output_path")

        pdf_doc = fitz.open()
        for img_path in image_paths:
            img = fitz.open(img_path)
            rect = img[0].rect
            pdf_bytes = img.convert_to_pdf()
            img.close()
            
            img_pdf = fitz.open("pdf", pdf_bytes)
            page = pdf_doc.new_page(width=rect.width, height=rect.height)
            page.show_pdf_page(rect, img_pdf, 0)
            img_pdf.close()

        pdf_doc.save(output_path)
        pdf_doc.close()
        return json_res({"success": True, "output": output_path})
    except Exception as e:
        return json_res({"error": str(e)}, 500)

# 5. PDF to DOCX
@app.route('/convert/pdf-to-docx', method='POST')
def pdf_to_docx():
    try:
        data = request.json
        input_path = data.get("input_path")
        output_path = data.get("output_path")

        cv = Converter(input_path)
        cv.convert(output_path, start=0, end=None)
        cv.close()

        return json_res({"success": True, "output": output_path})
    except Exception as e:
        return json_res({"error": str(e)}, 500)

# 6. PDF Tables to CSV
@app.route('/convert/pdf-to-csv', method='POST')
def pdf_to_csv():
    try:
        data = request.json
        input_path = data.get("input_path")
        output_path = data.get("output_path")

        extracted_rows = []
        with pdfplumber.open(input_path) as pdf:
            for page in pdf.pages:
                tables = page.extract_tables()
                for table in tables:
                    for row in table:
                        cleaned = [cell.strip() if cell else "" for cell in row]
                        extracted_rows.append(cleaned)

        df = pd.DataFrame(extracted_rows[1:], columns=extracted_rows[0] if extracted_rows else None) if extracted_rows else pd.DataFrame()
        df.to_csv(output_path, index=False, encoding="utf-8")
        return json_res({"success": True, "output": output_path})
    except Exception as e:
        return json_res({"error": str(e)}, 500)

# 7. DOCX Helpers
@app.route('/doc/read-docx', method='POST')
def read_docx():
    try:
        data = request.json
        doc = Document(data.get("input_path"))
        return json_res({"success": True, "text": "\n".join([p.text for p in doc.paragraphs])})
    except Exception as e:
        return json_res({"error": str(e)}, 500)

@app.route('/doc/html-to-docx', method='POST')
def html_to_docx():
    try:
        data = request.json
        doc = Document()
        HtmlToDocx().add_html_to_document(data.get("html", ""), doc)
        doc.save(data.get("output_path"))
        return json_res({"success": True, "output": data.get("output_path")})
    except Exception as e:
        return json_res({"error": str(e)}, 500)

# 8. PPTX Export
@app.route('/presentation/export-pptx', method='POST')
def export_pptx():
    try:
        data = request.json
        prs = Presentation()
        prs.slide_width, prs.slide_height = Inches(13.333), Inches(7.5)
        for s_info in data.get("slides", []):
            slide = prs.slides.add_slide(prs.slide_layouts[6])
            for el in s_info.get("elements", []):
                left = Inches(float(el.get("x", 0.1)) * 13.333)
                top = Inches(float(el.get("y", 0.1)) * 7.5)
                w = Inches(float(el.get("width", 0.5)) * 13.333)
                h = Inches(float(el.get("height", 0.15)) * 7.5)
                txBox = slide.shapes.add_textbox(left, top, w, h)
                tf = txBox.text_frame
                tf.word_wrap = True
                p = tf.paragraphs[0]
                p.text = el.get("text", "")
                p.font.size = Pt(float(el.get("fontSize", 24)))
                hx = el.get("color", "#000000").lstrip('#')
                if len(hx) == 6:
                    p.font.color.rgb = RGBColor(*(int(hx[i:i+2], 16) for i in (0, 2, 4)))
        prs.save(data.get("output_path"))
        return json_res({"success": True, "output": data.get("output_path")})
    except Exception as e:
        return json_res({"error": str(e)}, 500)

# Startup entrypoint required by serious_python
if __name__ == '__main__':
    app.run(host='127.0.0.1', port=50050, quiet=True)
