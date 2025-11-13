from flask import Flask, jsonify
import os

app = Flask(__name__)

@app.route('/')
def home():
    return jsonify({
        "message": "Welcome to CloudNorth Backend API",
        "status": "success", 
        "version": "1.0.0"
    })

@app.route('/api/products')
def get_products():
    products = [
        {"id": 1, "name": "CloudNorth T-Shirt", "price": 29.99},
        {"id": 2, "name": "CloudNorth Hoodie", "price": 59.99},
        {"id": 3, "name": "CloudNorth Cap", "price": 19.99}
    ]
    return jsonify(products)

@app.route('/api/health')
def health():
    return jsonify({"status": "healthy", "service": "backend"})

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000, debug=True)
