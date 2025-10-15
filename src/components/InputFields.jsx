import React from "react";
function InputFields({ label, placeholder, onChange }) {
  return (
    <div>
      <div className="font-medium text-slate-600 p-2 ">{label}</div>
      <input
        placeholder={placeholder}
        className=" border border-slate-400 rounded-md p-2 w-full"
        onChange={onChange}
      ></input>
    </div>
  );
}

export default InputFields;
