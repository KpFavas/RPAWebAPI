import json
from flask import Flask, request, jsonify
from robot.run import run

app = Flask(__name__)

bearer_token = "Test@123"   #bearer token

@app.route('/run-robot-test', methods=['POST'])
def run_robot_test():
    if request.headers.get('Content-Type') == 'application/json':
        # Check if the Authorization header is present
        if 'Authorization' not in request.headers:
            return jsonify({'error': 'Missing Authorization header'}), 401

        # Extract the Bearer token from the Authorization header
        auth_header = request.headers['Authorization']
        auth_parts = auth_header.split()
        if len(auth_parts) != 2 or auth_parts[0] != 'Bearer':
            return jsonify({'error': 'Invalid Authorization header'}), 401

        token = auth_parts[1]

        if token != bearer_token:
            return jsonify({'error': 'Invalid Bearer token'}), 401      #checking the token

        data = request.get_json()
        
        # Check if all required variables are present in the request body
        required_variables = ['BaseUrl', 'Username', 'Password', 'From_Date', 'To_Date', 'BankAccountCode', 'BankChargeAccountCode','ExcelData']
        missing_variables = [var for var in required_variables if var not in data]
        if missing_variables:
            error_message = f"Missing variables: {', '.join(missing_variables)}"
            return jsonify({'error': error_message}), 400

        # Create the variable dictionary
        variable_dict = {
            "BaseUrl": data.get('BaseUrl'),
            "Username": data.get('Username'),
            "Password": data.get('Password'),
            "From_Date": data.get('From_Date'),
            "To_Date": data.get('To_Date'),
            "BankAccountCode": data.get('BankAccountCode'),
            "BankChargeAccountCode": data.get('BankChargeAccountCode'),
            "ExcelData": data.get('ExcelData', [])
        }

        # Store values in a JSON file
        with open('variables.json', 'w') as f:
            json.dump(variable_dict, f)

        run('robtest.robot')
        response_code=200
        response = {
            "message": "Robot Test Completed"
        }
        return jsonify(response),response_code
    else:
        return jsonify({'error': 'Invalid Content-Type. Expected application/json.'}), 415

if __name__ == "__main__":
    app.run()