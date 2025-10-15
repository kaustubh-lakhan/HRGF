import React, { useState } from "react";
import { useSearchParams } from "react-router-dom";
import axios from "axios";
import { useNavigate } from "react-router-dom";

function SendMoney() {
  const naviagte = useNavigate();
  const [searchParams] = useSearchParams();
  const id = searchParams.get("id");
  const firstName = searchParams.get("firstName");
  const lastName = searchParams.get("lastName");

  const [amount, setAmount] = useState(0);

  return (
    <div className="flex justify-center items-center">
      <div className="flex-col border rounded-md w-fit p-6 my-4">
        <div className="text-xl font-bold p-2 flex justify-center">
          Send Money
        </div>
        <div className="flex">
          <div className="h-10 w-10 bg-green-500 text-white rounded-full flex items-center justify-center font-bold">
            {firstName[0].toUpperCase() + lastName[0].toUpperCase()}
          </div>
          <div className="p-2 font-semibold text-slate-600">
            {firstName + " " + lastName}
          </div>
        </div>
        <div>
          <div className="font-medium text-slate-600 p-2 ">Amount (in Rs)</div>
          <input
            placeholder="Enter Amount"
            className=" border border-slate-400 rounded-md p-2 w-full"
            onChange={(e) => {
              setAmount(e.target.value);
            }}
          ></input>
        </div>
        <button
          type="button"
          className="text-white bg-green-500 hover:bg-gray-900 focus:outline-none focus:ring-4 focus:ring-gray-300 font-medium rounded-lg text-sm px-5 py-2.5 me-2 mb-2 dark:bg-gray-800 dark:hover:bg-gray-700 dark:focus:ring-gray-700 dark:border-gray-700
        my-4 w-full"
          onClick={async () => {
            const token = localStorage.getItem("token");
            const response = await axios.post(
              "http://host.docker.internal:3000/api/vi/account/transfer",
              {
                amount,
                to: id,
              },
              {
                headers: {
                  Authorization: "Bearer " + token,
                },
              }
            );
            naviagte("/dashboard");
          }}
        >
          Send Money
        </button>
      </div>
    </div>
  );
}

export default SendMoney;
