import subprocess
import tempfile
from fastapi import FastAPI, UploadFile, File, Form
from fastapi.responses import FileResponse, HTMLResponse
import fitz  # PyMuPDF
import pandas as pd
from jinja2 import Template
import pdfplumber
from pdf2docx import Converter

app = FastAPI(title="Office SuperApp Processing Engine")

# 1. Spreadsheet to HTML
@app.post("/convert/sheet-to-html")
async def sheet_to_html(file: UploadFile = File(...)):
    df = pd.read_excel(file.file) if file.filename.endswith(('.xlsx', '.xls')) else pd.read_csv(file.file)
    
    html_template = """
    <!DOCTYPE html>
    <html>
    <head>
      <style>
        table { border-collapse: collapse; width: 100%; font-family: sans-serif; }
        th, td { border: 1px solid #ddd; padding: 8px; text-align: left; }
        th { background-color: #2b579a; color: white; }
        tr:nth-child(even) { background-color: #f2f2f2; }
      </style>
    </head>
    <body>
      <h2>Exported Report</h2>
      {{ table_data }}
    </body>
    </html>
    """
    rendered = Template(html_template).render(table_data=df.to_html(classes="table", index=False))
    return HTMLResponse(content=rendered)

# 2. PDF Operations: Merge
@app.post("/pdf/merge")
async def merge_pdfs(files: list[UploadFile] = File(...)):
    result_doc = fitz.open()
    for uploaded in files:
        sub_doc = fitz.open(stream=await uploaded.read(), filetype="pdf")
        result_doc.insert_pdf(sub_doc)
        
    out_path = tempfile.mktemp(suffix=".pdf")
    result_doc.save(out_path)
    return FileResponse(out_path, filename="merged.pdf", media_type="application/pdf")

# 3. PDF Operations: Split
@app.post("/pdf/split")
async def split_pdf(file: UploadFile = File(...), from_page: int = Form(...), to_page: int = Form(...)):
    doc = fitz.open(stream=await file.read(), filetype="pdf")
    sub_doc = fitz.open()
    sub_doc.insert_pdf(doc, from_page=from_page - 1, to_page=to_page - 1)
    
    out_path = tempfile.mktemp(suffix=".pdf")
    sub_doc.save(out_path)
    return FileResponse(out_path, filename=f"split_p{from_page}_p{to_page}.pdf", media_type="application/pdf")

# 4. Convert Office to PDF via Headless LibreOffice
@app.post("/convert/office-to-pdf")
async def office_to_pdf(file: UploadFile = File(...)):
    with tempfile.NamedTemporaryFile(delete=False, suffix=f"_{file.filename}") as tmp:
        tmp.write(await file.read())
        tmp_path = tmp.name

    subprocess.run([
        "libreoffice", "--headless", "--convert-to", "pdf",
        tmp_path, "--outdir", tempfile.gettempdir()
    ], check=True)

    pdf_path = tmp_path.rsplit(".", 1)[0] + ".pdf"
    return FileResponse(pdf_path, filename="converted.pdf", media_type="application/pdf")

# 5. PDF to DOCX
@app.post("/convert/pdf-to-docx")
async def pdf_to_docx(file: UploadFile = File(...)):
    with tempfile.NamedTemporaryFile(delete=False, suffix=".pdf") as in_pdf:
        in_pdf.write(await file.read())
        in_pdf_path = in_pdf.name
        
    out_docx_path = tempfile.mktemp(suffix=".docx")
    cv = Converter(in_pdf_path)
    cv.convert(out_docx_path, start=0, end=None)
    cv.close()
    
    return FileResponse(out_docx_path, filename="converted.docx")

# 6. PDF to CSV / Excel
@app.post("/convert/pdf-to-csv")
async def pdf_to_csv(file: UploadFile = File(...)):
    extracted_tables = []
    with pdfplumber.open(file.file) as pdf:
        for page in pdf.pages:
            tables = page.extract_tables()
            for table in tables:
                extracted_tables.extend(table)
                
    df = pd.DataFrame(extracted_tables[1:], columns=extracted_tables[0] if extracted_tables else None)
    out_path = tempfile.mktemp(suffix=".csv")
    df.to_csv(out_path, index=False)
    return FileResponse(out_path, filename="extracted_table.csv")
