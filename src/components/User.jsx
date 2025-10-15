import React, { useState, useEffect } from "react";
import ReceiverProfile from "./ReceiverProfile";
import axios from "axios";

function User() {
  const [users, setUsers] = useState([]);
  const [filter, setFilter] = useState("");

  useEffect(
    function () {
      const token = localStorage.getItem("token");
      // axios
      //   .get("http://localhost:3000/api/vi/user/bulk?filter=" + filter, {
      //     headers: {
      //       Authorization: "Bearer " + token,
      //     },
      //   })
      //   .then((response) => {
      //     setUsers(response.data.users);
      //   });
      const filterfetching = setTimeout(() => {
        axios
          .get(
            "http://host.docker.internal:3000/api/vi/user/bulk?filter=" +
              filter,
            {
              headers: {
                Authorization: "Bearer " + token,
              },
            }
          )
          .then((response) => {
            setUsers(response.data.users);
          });
      }, 1000);
      return () => {
        clearTimeout(filterfetching);
      };
    },
    [filter]
  );

  // console.log(users);

  return (
    <div className="flex-col m-2 border rounded-md p-2">
      <div className="font-bold p-2">User</div>
      <input
        className=" border border-slate-400 rounded-md p-2 w-full"
        placeholder="Search User"
        onChange={(e) => {
          const filt = e.target.value;
          setFilter(filt);
        }}
      ></input>
      {/* <ReceiverProfile></ReceiverProfile> */}
      {users.map((user) => {
        return (
          <div>
            <ReceiverProfile user={user}></ReceiverProfile>
          </div>
        );
      })}
    </div>
  );
}

export default User;
