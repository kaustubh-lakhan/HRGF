import React from "react";
import AppBar from "../components/AppBar";
import Balance from "../components/Balance";
import User from "../components/User";
import ReceiverProfile from "../components/ReceiverProfile";

function DashBoard() {
  return (
    <div className="w-full m-2">
      <AppBar></AppBar>
      <Balance></Balance>
      <User></User>
    </div>
  );
}

export default DashBoard;
