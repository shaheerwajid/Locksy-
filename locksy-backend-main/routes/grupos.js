const { Router } = require("express");
const { validarJWT } = require("../middlewares/validar-jwt");

const {
  addGroup,
  addMember,
  removeGroup,
  removeMember,
  groupMembers,
  updateGroup,
  groupByCode,
  groupsByMember,
  updatGroupDisappearTime,
} = require("../controllers/grupos");

const router = Router();

router.post("/addGroup", validarJWT, addGroup);
router.post("/removeGroup", validarJWT, removeGroup);

router.post("/addMember", validarJWT, addMember);
router.post("/removeMember", validarJWT, removeMember);

router.post("/groupMembers", groupMembers);
router.post("/updateGroup", updateGroup);

router.post("/groupByCode", groupByCode);
router.post("/groupsByMember", groupsByMember);

router.post("/update-disappear-time", validarJWT, updatGroupDisappearTime);

module.exports = router;
