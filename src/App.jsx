import React from "react";
import { BrowserRouter, Route, Routes } from "react-router-dom";
import SignUpCard from "./pages/Signup";
import Signin from "./pages/Signin";
import DashBoard from "./pages/Dashboard";
import SendMoney from "./pages/SendMoney";
function App() {
  return (
    <div className="flex justify-center items-center">
      <BrowserRouter>
        <Routes>
          <Route path="/" element={<Signin />}></Route>
          <Route path="/signup" element={<SignUpCard />}></Route>
          <Route path="/signin" element={<Signin />}></Route>
          <Route path="/dashboard" element={<DashBoard />}></Route>
          <Route path="/sendmoney" element={<SendMoney />}></Route>
        </Routes>
      </BrowserRouter>
    </div>
  );
}

export default App;
