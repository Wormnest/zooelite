class Looper {

}

Looper:Loop() {
	local task_list = [];
	local i = 0;
	//we always loop if we don't have enough cash
	while(AICompany.GetBankBalance(AICompany.COMPANY_SELF) < 100000) {
		this.Sleep(200);
		LogManager.Log("waiting for money", 4);
		local next_task = task_list[i];
		next_task.Exectute();
		i++;
	}
}