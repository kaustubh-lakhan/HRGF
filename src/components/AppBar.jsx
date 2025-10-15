import React from "react";

function AppBar() {
  return (
    <div className="flex justify-between mt-2 border rounded-md">
      <div className="font-semibold text-slate-600 p-4">PayTM DashBoard</div>
      <div className="flex justify-center items-center p-2">
        <div className="mx-2 font-medium">Hello</div>
        <div className="mx-2 bg-black text-white h-10 w-10 rounded-full flex justify-center items-center font-bold">
          Us
        </div>
      </div>
    </div>
  );
}

export default AppBar;
