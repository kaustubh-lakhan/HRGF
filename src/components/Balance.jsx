import React, { useEffect, useState } from "react";
import axios from "axios";

function Balance() {
  const [balance, SetBalance] = useState(0);
  useEffect(() => {
    axios
      .get("http://host.docker.internal:3000/api/vi/account/balance", {
        headers: {
          Authorization: "Bearer " + localStorage.getItem("token"),
        },
      })
      .then((response) => {
        SetBalance(response.data.balance);
      });
  }, [balance]);

  return (
    <div className="flex m-2 border rounded-md p-2">
      <div className="font-medium text-slate-800 p-2">Your Balance : </div>
      <div className="font-semibold text-slate-900 p-2">RS {balance}</div>
    </div>
  );
}

export default Balance;
