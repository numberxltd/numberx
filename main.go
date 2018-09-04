package main

import (
	"fmt"
	"math/rand"
	"time"
)

func main() {
	//rand.Seed(time.Now().UnixNano()+109)

	fmt.Printf("| players | invest | profit | [0,33] | [85-95]| [96-99] | [100 & lucky number]| (100,+] | (33,80] | jackpot left | compot left|\n| ------ | ------ | ------ | ------ | ------ | ------ |------ | ------ | ------ | ------ | ------ |\n")
	// 这个循环是 为了拿上面十次结果。按开始设计的计算下来 雪崩，奖池jackpot最后是负的。不行，
	// 下面是调过的数值
	for z := 1; z <= 20; z++ {
		res25 := 0
		res80 := 0
		res90 := 0
		res100 := 0
		resdone := 0   // >100 次数
		rescancel := 0 // 用户取消次数
		resreward := 0.0
		jackpot := 0.0 // 奖池数量
		compot := 0.0  // 团队奖池
		invest := 0.0    // 投资多少钱，因为假设每次都投资1eth 则次数就是投资额

		// 两千个用户来玩一次游戏
		for i := 0; i < z*500; i++ {
			comment := ""
			res := 0
			x := 0.0
			rand.Seed(time.Now().UnixNano() + int64(i))
			r := rand.Intn(50)
			r += 45
			luckynum := r
			for j := 1; j < 10; j++ {
				// 假装用户心理，如果抽出来的牌之和 小于75 应该会再抽一张
				if (res <= 76) {
					invest += 0.1
					jackpot += 0.099 // 99%进入奖池
					compot += 0.001  // 1% 进入团队
					//rand.Seed(time.Now().UnixNano()+int64(i))
					v := rand.Intn(100)                        // 随机一张牌
					res += v                                   // 计算总和
					comment = comment + fmt.Sprintf("%d--", v) // console.log 注释

					if (res <= 33 && j >= 3) {
						x = float64(j) / 10
						break
					}

					if (res == luckynum) {
						x = float64(j) / 10
						break
					}
				} else {
					x = float64(j) / 10 // x代表 这个用户抽了几张牌，也代表了这个用户投了多少eth 因为假设每次投1eth
					break
				}

			}
			comment += fmt.Sprintf(" :%v ", res)

			// 如果到了现在 总和小于 85 则 假设用户会放弃此轮
			// 则已经加到奖池的钱 要减去此轮的50% 还给用户
			// 剩下的平分给团队和奖池
			if res <= 85 && res != luckynum {
				jackpot -= float64(x) * 0.99
				jackpot += float64(x) * 0.99 * 2 / 3
				//compot += float64(x) * 0.99 / 4
				resreward += float64(x) * 0.99 / 3
				rescancel ++
				comment += fmt.Sprintf(" =================")
			}

			//fmt.Println(comment)
			// 1.5倍
			if res > 85 && res <= 95 {
				res80 ++
				resb := float64(x) * 1.5
				resreward += resb
				jackpot -= resb
			}

			// 3倍
			if res > 95 && res <= 99 {
				res90 ++
				resb := float64(x) * 2.5
				jackpot -= resb
				resreward += resb
			}

			// 5倍+3%奖池
			if (res == 100 || res == luckynum) {
				res100 ++
				resb := float64(x)*3.6 + jackpot*2/100
				jackpot -= resb
				resreward += resb
				//fmt.Println("00000000000000000comment:",comment)
			}

			// 5倍+3%奖池
			if (x >= 0.3 && res <= 33) {
				res25 ++
				resb := float64(x)*3.6 + jackpot*3/100
				jackpot -= resb
				resreward += resb
				//fmt.Println("==================================22222222222comment:",comment)
			}

			// 爆仓 给1%给团队
			if res > 100 {
				resdone ++
				compot += float64(x) / 100
				jackpot -= float64(x) / 100
				//chomment += fmt.Sprintf(" =================")
			}
		}
		//fmt.Println("resreward:",resreward)

		//if jackpot <= 0 {
		//	fmt.Println("==========<0 ")
		//}
		fmt.Printf("|%d|%0.2f|%0.2f|%d|%d|%d|%d|%d|%d|%0.2f|\n",
			z*500,invest, resreward, res25, res80, res90, res100, resdone, rescancel, jackpot)
	}
}
