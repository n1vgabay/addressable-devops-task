from flask import Flask,jsonify
import serverless_wsgi

app = Flask(_name_)

@app.route('/', methods=['GET'])
def Hello():
    return 'Hello from AWS Lambda using Python'

@app.route('/greet', methods=['GET'])
def Greet():
    return 'greet from AWS Lambda using Python !'

def handler(event, context):
    return serverless_wsgi.handle_request(app, event, context)