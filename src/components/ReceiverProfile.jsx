import axios from "axios";
import React from "react";
import { useNavigate } from "react-router-dom";
function ReceiverProfile({ user, onClick }) {
  const navigate = useNavigate();
  return (
    <div className="flex justify-between  m-2 border rounded-md p-2">
      <div className="flex p-2 justify-center items-center">
        <div className="h-10 w-10 bg-slate-700 text-white rounded-full flex items-center justify-center font-bold">
          {user.firstName[0].toUpperCase() + user.lastName[0].toUpperCase()}
        </div>
        <div className="p-2 font-semibold text-slate-600">
          {user.firstName + " " + user.lastName}
        </div>
      </div>
      <div>
        <button
          type="button"
          className="text-white bg-gray-800 hover:bg-gray-900 focus:outline-none focus:ring-4 focus:ring-gray-300 font-medium rounded-lg text-sm px-5 py-2.5  dark:bg-gray-800 dark:hover:bg-gray-700 dark:focus:ring-gray-700 dark:border-gray-700
           w-full my-2"
          onClick={() => {
            navigate(
              "/SendMoney?id=" +
                user._id +
                "&firstName=" +
                user.firstName +
                "&lastName=" +
                user.lastName
            );
          }}
        >
          Send Money
        </button>
      </div>
    </div>
  );
}

export default ReceiverProfile;
