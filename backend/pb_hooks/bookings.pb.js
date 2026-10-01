/// <reference path="../pb_data/types.d.ts" />
// Reject a booking that ends before it starts or overlaps another booking of the
// same equipment. Checked and inserted in one transaction so two people can't
// grab the same slot at the same moment.
onRecordCreateExecute((e) => {
  e.app.runInTransaction((txApp) => {
    const start = e.record.getString("start")
    const end = e.record.getString("end")
    if (!start || !end || end <= start) throw new BadRequestError("End time must be after start time.")

    // PocketBase stores dates as sortable UTC strings, so string comparison is time order.
    const clash = txApp.findRecordsByFilter(
      "bookings",
      "equipment = {:eq} && start < {:end} && end > {:start}",
      "start", 1, 0,
      { eq: e.record.getString("equipment"), start, end },
    )
    if (clash.length) throw new BadRequestError("That slot overlaps an existing booking.")

    e.app = txApp
    e.next()
  })
}, "bookings")
